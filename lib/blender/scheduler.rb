#
# Author:: Ranjib Dey (<ranjib@pagerduty.com>)
# Copyright:: Copyright (c) 2014 PagerDuty, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'blender/log'
require 'blender/utils/thread_pool'
require 'blender/exceptions'
require 'blender/scheduling_strategies/default'
require 'blender/scheduling_strategies/per_host'
require 'blender/scheduling_strategies/per_task'
require 'blender/utils/thread_pool'
require 'blender/scheduler/dsl'
require 'blender/event_dispatcher'
require 'blender/handlers/doc'
require 'blender/tasks/base'
require 'thread_safe'

module Blender
  class Scheduler
    include SchedulerDSL
    include Lock

    attr_reader :metadata, :name
    attr_reader :scheduling_strategy
    attr_reader :events, :tasks
    attr_reader :lock_properties

    # options
    #   noop: true/false - No-Op mode, dont invoke job.run
    #   arguments: array or any stock data
    #   rest everything gets merged as metadata
    def initialize(name, tasks = ThreadSafe::Array.new, options = {})
      @name = name
      @tasks = tasks
      @events = Blender::EventDispatcher.new
      @config = ThreadSafe::Hash.new{ ThreadSafe::Hash.new }
      @config[:noop] = options[:noop] || false
      @config[:arguments] = options[:arguments] || []
      unless options.delete(:no_doc)
        events.register(Blender::Handlers::Doc.new)
      end
      @metadata = default_metadata.merge(options)
      @scheduling_strategy = nil
      @lock_properties = {driver: nil, driver_options: {}}
    end

    def run
      @scheduling_strategy ||= SchedulingStrategy::Default.new
      events.run_started(self)
      events.job_computation_started(scheduling_strategy)
      jobs = scheduling_strategy.compute_jobs(@tasks)
      events.job_computation_finished(self, jobs)
      lock do
        if metadata[:concurrency] > 1
          concurrent_run(jobs)
        else
          serial_run(jobs)
        end
        events.run_finished(self)
        jobs
      end
    rescue StandardError => e
      events.run_failed(self, e)
      raise e
    end

    def serial_run(jobs)
      Log.debug('Invoking serial run')
      jobs.each do |job|
        run_job(job)
      end
    end

    def concurrent_run(jobs)
      c = metadata[:concurrency]
      Log.debug("Invoking concurrent run with concurrency:#{c}")
      pool = Utils::ThreadPool.new(c)
      jobs.each do |job|
        pool.add_job do
          run_job(job)
        end
      end
      pool.run_till_done
    end

    def run_job(job)
      events.job_started(job)
      Log.debug("Running job #{job.name}")
      unless blender_config(:noop)
        job.run
      end
      events.job_finished(job)
    rescue StandardError => e
      events.job_failed(job, e)
      if metadata[:ignore_failure]
        Log.warn("Exception: #{e.inspect} was suppressed, ignoring failure")
      else
        raise e
      end
    end

    def blender_config(key)
      @config[key]
    end

    def update_config(key, value)
      @config[key] = value
      @config
    end

    def default_metadata
      temp = ThreadSafe::Hash.new
      temp[:ignore_failure] = false
      temp[:concurrency] = 0
      temp[:handlers] = ThreadSafe::Array.new
      temp[:members] = ThreadSafe::Array.new
      temp
    end
  end
end

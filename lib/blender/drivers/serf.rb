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

require 'serfx'
require 'blender/exceptions'
require 'blender/log'
require 'blender/drivers/base'

module Blender
  module Driver
    class Serf < Base

      def filter_by
        @config[:filter_by]
      end

      def serf_query(command, host)
        responses = []
        Log.debug("Invoking serf query '#{command.query}' with payload '#{command.payload}' against #{@current_host}")
        Log.debug("Serf RPC address #{@config[:host]}:#{@config[:port]}")
        serf_config = {
          host: @config[:host],
          port: @config[:port],
          authkey: @config[:authkey]
        }
        Serfx.connect(serf_config) do |conn|
          conn.query(*query_opts(command, host)) do |event|
            responses <<  event
            stdout.puts event.inspect
          end
        end
        responses
      end

      def run_command(command, host)
        begin
          responses = serf_query(command, host)
          if command.process
            command.process.call(responses)
          end
          ExecOutput.new(exit_status(responses), responses.inspect, '')
        rescue StandardError => e
          ExecOutput.new( -1, '', e.message)
        end
      end

      def exit_status(responses)
        case filter_by
        when :host
          responses.size == 1 ? 0 : -1
        when :tag
          0
        else
          raise ArgumentError, "Unknown filter_by option: #{@config[:filter_by]}"
        end
      end

      def query_opts(command, host)
        opts = { Timeout: (command.timeout || 15)*1e9.to_i}
        case filter_by
        when :host
          opts.merge!(FilterNodes: [host])
        when :tag
          opts.merge!(FilterTags: {@config[:filter_tag] => host})
        else
          raise ArgumentError, "Unknown filter_by option: #{@config[:filter_by]}"
        end
        [ command.query, command.payload, opts]
      end

      def execute(tasks, hosts)
        Log.debug("Serf query on #{filter_by}s [#{hosts.inspect}]")
        tasks.each do |task|
          hosts.each do |host|
            events.command_started(task.command)
            cmd = run_command(task.command, host)
            events.command_finished(task.command, cmd)
            if cmd.exitstatus != 0 and !task.metadata[:ignore_failure]
              raise Exceptions::ExecutionFailed, cmd.stderr
            end
          end
        end
      end

      private

      def default_config
        super.merge(filter_by: :host)
      end
    end
  end
end

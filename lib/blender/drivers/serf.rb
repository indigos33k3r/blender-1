require 'serfx'
require 'blender/exceptions'
require 'blender/log'
require 'blender/drivers/base'

module Blender
  module Driver
    class Serf < Base

      def raw_exec(command)
        responses = []
        Log.debug("Invoking serf query '#{command.query}' with payload '#{command.payload}' against #{@current_host}")
        Log.debug("Serf RPC address #{@config[:host]}:#{@config[:port]}")
        serf_config = {
          host: @config[:host],
          port: @config[:port],
          authkey: @config[:authkey]
        }
        query_opts = {
         FilterNodes: [@current_host],
         Timeout: (command.timeout || 15)*1e9.to_i
        }
        Serfx.connect(serf_config) do |conn|
          conn.query(command.query, command.payload,) do |event|
            responses <<  event
            puts event.inspect
          end
        end
        exit_status = responses.size == 1 ? 0 : -1
        ExecOutput.new(exit_status, responses.inspect, '')
      end

      def execute(job)
        tasks = job.tasks
        hosts = job.hosts
        Log.debug("Serf execution tasks [#{tasks.inspect}]")
        Log.debug("Serf query on hosts [#{hosts.inspect}]")
        Array(hosts).each do |host|
          @current_host = host
          Array(tasks).each do |task|
            if evaluate_guards?(task)
              Log.debug("Host:#{host}| Guards are valid")
            else
              Log.debug("Host:#{host}| Guards are invalid")
              run_task_command(task)
            end
          end
        end
      end

      def run_task_command(task)
         e_status = raw_exec(task.command).exitstatus
         if e_status != 0
           if task.metadata[:ignore_failure]
             Log.warn('Ignore failure is set, skipping failure')
           else
            raise Exceptions::ExecutionFailed, "Failed to execute '#{task.command}'"
           end
         end
      end
    end
  end
end

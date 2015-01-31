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

require 'blender/tasks/ssh'

module Blender
  module Task
    class Scp < Blender::Task::Base
      def initialize(name, metadata = {})
        super
        @command = Struct.new(:source, :target).new
        @command.target = name
        @command.source = name
      end
    end

    class ScpUpload < Blender::Task::Scp
      def from(source)
        @command.source = source
      end
    end

    class ScpDownload < Blender::Task::Scp
      def to(target)
        @command.target = target
      end
    end
  end
end

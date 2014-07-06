require 'chef/search/query'

module Blender
  module Discovery
    class ChefDiscovery
      def initialize(options)
        if options[:config_file]
          Chef::Config.from_file options[:config_file]
        end

        if options[:node_name]
          Chef::Config[:node_name] = options[:node_name]
        end

        if options[:client_key]
          Chef::Config[:client_key] = options[:client_key]
        end
        @attribute = options[:attribute] || 'fqdn'
      end

      def search(search_term)
        q = Chef::Search::Query.new
        res = q.search(:node, search_term)
        res.first.collect{|n| node_attribute(n, @attribute)}
      end

      private
      def node_attribute(data, nested_value_spec)
        nested_value_spec.split(".").each do |attr|
          if data.nil?
            nil # don't get no method error on nil
          elsif data.respond_to?(attr.to_sym)
            data = data.send(attr.to_sym)
          elsif data.respond_to?(:[])
            data = data[attr]
          else
            data = begin
              data.send(attr.to_sym)
            rescue NoMethodError
              nil
            end
          end
        end
        ( !data.kind_of?(Array) && data.respond_to?(:to_hash) ) ? data.to_hash : data
      end
    end
  end
end
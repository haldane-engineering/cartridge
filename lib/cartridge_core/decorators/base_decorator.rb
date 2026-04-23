# frozen_string_literal: true

require 'ostruct'

module CartridgeCore
  module Decorators
    class SimpleDecorator
      attr_accessor :context
      attr_reader :object

      def initialize(object, opts = {})
        @object = object
        @context = OpenStruct.new(**opts)
      end

      protected

      attr_reader :extra

      class << self
        def decorate_collection(collection:, opts: {})
          collection.map { |object| new(object, opts) }
        end

        def delegate_all
          define_method(:method_missing) do |method_name, *args|
            return object.send(method_name, *args) if object.respond_to?(method_name)

            super(method_name, *args)
          end
        end

        def include_in_json(*methods)
          define_method(:as_json) do |*args|
            included_hash = methods.index_with do |_method|
              send(_method)
            end
            object.send(:as_json, *args).merge(included_hash)
          end
        end

        def decorate(relation, context: {})
          new(relation, context)
        end

        protected

        def auto_delegate(*methods)
          delegate(*methods, to: :object)
        end
      end
    end
  end
end

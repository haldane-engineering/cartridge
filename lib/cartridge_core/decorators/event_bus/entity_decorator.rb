# frozen_string_literal: true

module CartridgeCore
  module Decorators
    module EventBus
      class EntityDecorator < SimpleDecorator
        # decorates any of [Tree, Route, Stop]
        delegate_all

        def name
          # format the names
          # stop => tr_tree_name.ro_route_name.st_stop_name
          # route => tr_tree_name.ro_route_name
          # tree => tr_tree_name
          @name ||= parents.push(object).map(&method(:event_name_for)).join('.')
        end

        def base_metadata
          respond_to?(:commits) ? { with_commit_id: commits.last.id } : {}
        end

        private

        def parents
          @parents ||= case object.class
          when ::CartridgeCore::Entities::Stop then [route.timeline, route]
          when ::CartridgeCore::Entities::Route then [timeline]
          else []
          end
        end

        def event_name_for(entity)
          "#{entity.class.name.slice(0, 2).downcase}_#{entity.name}"
        end
      end
    end
  end
end

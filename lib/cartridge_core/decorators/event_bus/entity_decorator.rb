# frozen_string_literal: true

module CartridgeCore
  module Decorators
    module EventBus
      class EntityDecorator < BaseDecorator
        # decorates any of [Tree, Route, Stop]
        delegate_all

        def name
          # format the names
          # stop => tr_tree_name.ro_route_name.st_stop_name
          # route => tr_tree_name.ro_route_name
          # tree => tr_tree_name
          @name ||= parents.push(obj).map(&method(:event_name_for)).join('.')
        end

        def base_metadata
          obj.respond_to?(:commits) ?  { with_commit_id: commits.last.id } : {}
        end

        private

        def parents
          @parents ||= case obj.class
          when Stop then [route.timeline, route]
          when Route then [timeline]
          else []
          end
        end

        def event_name_for(entity) = "#{entity.class.name.slice(0, 2).downcase}_#{entity.name}"

        # def event_name_for(entity)
,
        #   case entity.class
        #   when Stop then "st_#{entity.name}"
        #   when Route then "ro_#{entity.name}"
        #   when Tree then "tr_#{entity.name}"
        #   when Check then "ch_#{entity.name}"
        #   when balancer then "ba_#{balancer}"
        #   end
        # end
      end
    end
  end
end

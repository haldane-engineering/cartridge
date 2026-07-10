# frozen_string_literal: true

module CartridgeCore
  module Services
    module EventBus
      module Concerns
        module Propagation
          def register_activity!(actor, title, **metadata)
            executor = ::CartridgeCore::Decorators::EventBus::EntityDecorator.decorate(self)
            actor =  ::CartridgeCore::Decorators::EventBus::EntityDecorator.decorate(actor)
            # Stops and routes respond to timeline, timelines do not. This will always be called by a timeline
            # I added a check anyway on the propagate method
            timeline = executor.object.try(:timeline) || executor
            timeline.propagate!(::CartridgeCore::Entities::EventBus::Event.new(
              title:,
              metadata: executor.base_metadata.merge(metadata),
              executor: executor.name,
              actor: actor.name,
              timeline_id: timeline.id,
              id: SecureRandom.hex(8),
            ))
          end

          # Just store in the events attribute (in Memory), at the end of orchestration
          # or at the next commit, it will commited to state -> see redis adapter.
          def propagate!(event) = events.unshift(event)

          def event(**opts)
            title = opts.delete(:title)
            actor, executor, metadata = opts.values_at(*%i(actor executor metadata))
            actor = ::CartridgeCore::Decorators::EventBus::EntityDecorator.decorate(actor) if actor
            executor = ::CartridgeCore::Decorators::EventBus::EntityDecorator.decorate(executor) if executor
            timeline = executor.try(:timeline) || executor
            search_opts = {
              title:,
              actor:    actor&.name,
              executor: executor&.name,
              metadata: (metadata || {}).compact,

            }.compact
            # using Array finders is in many ways inefficient because I imagine there might be millions of events for any
            # timeline instance -> Anyway this will be wrapped with the cache client's search
            # find should map a to_query -> which is then executed by the cache client
            #  Or NOT -> the event might not be available in the cache until the next commit whith is idiosyncratic
            # at this point
            timeline.events.find { |event| search_opts.entries.all? { |(k, v)| event.send(:"#{k}" == v) } }
          end
        end
      end
    end
  end
end

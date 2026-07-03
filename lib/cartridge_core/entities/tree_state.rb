# frozen_string_literal: true

# {
#   initial:       {},
#   current:       {},
#   context:       {},
#   changeset:     [],
#   activity_logs: [{ title:, timestamp:, origin:, meta: }],
#   version:       __version_id,
#   commits:       [:'009fxcv'],
#   head:          _latest_commit_id,
#   routes:        {
#     route_1: {
#       applied:      true,
#       tree_state:   { initial: {}, current: {}, version: },
#       context:      Context.new,
#       activity_log: [{}],
#       changset:     [{ strategy:, value:, index:, origin: 'route_1/stop_1', created: :datetime }],
#       stops:        {
#         stop_1: {
#           applied:      true,
#           changes:      [{}],
#           activity_log: [{ name: :check_application_start, value: :checker_name }], # same as changes above
#         },
#       },
#     },
#   },
# }
module CartridgeCore
  module Entities
    STATE_KEYS = %i[
      version
      current
      final
      changes
      id
      commits
      main
      stop_processes
      stop_process_units
      scheduled_timeline_executions
      head
      parameters
      definition_id
      routes
    ]
    COMMIT_ID_SLICING_RANGE = (0..8)
    # Examp
    TreeState = Struct.new(*STATE_KEYS, keyword_init: true) do
      include ::CartridgeCore::Entities::Concerns::TreeState::StateOperations
      def self.state_keys = STATE_KEYS

      def persist!(strategy)
        # for now we're just going to write to cache
        # we'll send this to the various database engines and
        # build a reader from that
      end

      # @return [String]
      def generate_commit_identifier
        Digest::SHA256.hexdigest(current.to_json + definition_id)
        [COMMIT_ID_SLICING_RANGE]
      end
    end
  end
end

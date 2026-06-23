# frozen_string_literal: true

module Diderot
  module Workflows
    class Runner
      def self.call(**kwargs) = new.call(**kwargs)

      # @param [String] workflow - the workflow timeline to be run by cartridge
      def call(workflow:)
        # other orchestrator params include parameters for each of the stops in the workflow
        # an ideal implementation here will be to let cartridge return a timeline object that can now be
        # run!
        definitions = YAML.safe_load_file(File.expand_path('timelines.yml', __dir__)).deep_symbolize_keys
        orchestrator_params = { load_namespace: :diderot, definitions: }
        ::CartridgeCore::Orchestrator.call(workflow, **orchestrator_params)
      end
    end
  end
end

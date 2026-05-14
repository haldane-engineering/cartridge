# frozen_string_literal: true

module Diderot
  class Engine < ::Rails::Engine
    isolate_namespace Diderot

    config.autoload_paths << File.expand_path('../../lib', __dir__)

    initializer 'diderot.zeitwerk_config' do
      Rails.autoloaders.main.push_dir(File.expand_path('../../lib', __dir__), namespace: Diderot)
    end
  end
end

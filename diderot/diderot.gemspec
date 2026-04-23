# frozen_string_literal: true

require_relative 'lib/diderot/version'

Gem::Specification.new do |spec|
  spec.name        = 'diderot'
  spec.version     = Diderot::VERSION
  spec.authors     = ['']
  spec.email       = ['hasstrup.ezekiel@gmail.com']
  spec.homepage    = 'https://haldaneengineering.com'
  spec.summary     = 'Engine for generating video highlights'
  spec.description = 'Engine for generating video highlights'
  spec.license     = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = "'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://haldaneengineering.com'
  spec.metadata['changelog_uri'] = 'https://haldaneengineering.com'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  spec.add_dependency 'rails', '~> 6.1.7', '>= 6.1.7.10'
end

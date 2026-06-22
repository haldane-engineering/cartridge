# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = 'diderot'
  spec.version     = '0.1.0'
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

  spec.add_dependency 'annotate', '~> 3.2.0'
  spec.add_dependency 'capybara', '~>3.1.0'
  spec.add_dependency 'concurrent-ruby', '1.3.4'
  spec.add_dependency 'concurrent-ruby-ext'
  spec.add_dependency 'nokogiri', '~> 1.19', '>= 1.19.3'
  spec.add_dependency 'open3', '~> 0.2.1'
  spec.add_dependency 'pg', '~> 1.6'
  spec.add_dependency 'pry', '~> 0.14.2'
  spec.add_dependency 'rails', '~> 6.1.7', '>= 6.1.7.10'
  spec.add_dependency 'selenium-webdriver', '4.44.0'
end

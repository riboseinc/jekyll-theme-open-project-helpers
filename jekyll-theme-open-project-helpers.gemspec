# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name          = 'jekyll-theme-open-project-helpers'
  s.version       = '1.0.4'
  s.authors       = ['Ribose Inc.']
  s.email         = ['open.source@ribose.com']

  s.summary       = 'Helpers for the Open Project Jekyll theme'
  s.homepage      = 'https://github.com/riboseinc/jekyll-theme-open-project-helpers/'
  s.license       = 'MIT'

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r!^(test|spec|features)/!) }

  s.add_runtime_dependency 'jekyll', '~> 3.8'
  s.add_runtime_dependency 'git', '~> 1.4'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rubocop', '~> 0.50'

  s.require_paths = ["lib"]
end

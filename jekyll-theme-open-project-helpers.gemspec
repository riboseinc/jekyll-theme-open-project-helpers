# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name          = "jekyll-theme-open-project-helpers"
  s.version       = "2.1.8"
  s.authors       = ["Ribose Inc."]
  s.email         = ["open.source@ribose.com"]

  s.summary       = "Helpers for the Open Project Jekyll theme"
  s.homepage      = "https://github.com/riboseinc/jekyll-theme-open-project-helpers/"
  s.license       = "MIT"

  s.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r!^(test|spec|features)/!)
  end

  s.required_ruby_version = ">= 2.5.0"

  s.add_runtime_dependency "fastimage", "~> 2.1.4"
  s.add_runtime_dependency "git", "~> 1.4"
  s.add_runtime_dependency "jekyll", "~> 4.0"

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "rspec-command", "~> 1.0"
  s.add_development_dependency "rubocop", "~> 1.5.2"

  s.require_paths = ["lib"]
end

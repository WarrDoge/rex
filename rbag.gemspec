# frozen_string_literal: true

require_relative "lib/rbag/version"

Gem::Specification.new do |spec|
  spec.name          = "rbag"
  spec.version       = Rbag::VERSION
  spec.authors       = ["Dmitrii Dudko"]
  spec.summary       = "PEX for Ruby — pack a Ruby app into a single self-executing .rbag file"
  spec.homepage      = "https://github.com/WarrDoge/rbag"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*.rb", "bin/rbag"]
  spec.bindir        = "bin"
  spec.executables   = ["rbag"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "bundler"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-minitest", "~> 0.35"
  spec.metadata["rubygems_mfa_required"] = "true"
end

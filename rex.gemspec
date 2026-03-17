# frozen_string_literal: true

require_relative "lib/rex/version"

Gem::Specification.new do |spec|
  spec.name          = "rex"
  spec.version       = Rex::VERSION
  spec.authors       = ["WarrDoge"]
  spec.summary       = "PEX for Ruby — pack a Ruby app into a single self-executing .rex file"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb", "bin/rex"]
  spec.bindir        = "bin"
  spec.executables   = ["rex"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-minitest", "~> 0.35"
  spec.metadata["rubygems_mfa_required"] = "true"
end

# frozen_string_literal: true

require "rake/clean"
require "rake/testtask"

ENV["BUNDLE_PATH"] ||= "vendor/bundle"

# Ensure vendored dev gems (minitest, rubocop) are available
vendor_lib = File.expand_path("vendor/bundle/ruby/#{RUBY_VERSION.sub(/\.\d+$/, '.0')}/gems")
if Dir.exist?(vendor_lib)
  Dir.glob("#{vendor_lib}/*/lib").each { |p| $LOAD_PATH.unshift(p) unless $LOAD_PATH.include?(p) }
end

CLEAN.include("*.rbag", "*.gem", "pkg/")

# --- test ---

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/test_*.rb"
  t.verbose = false
end

desc "Run integration tests (requires network; set SKIP_INTEGRATION=0)"
task :test_integration do
  ENV["SKIP_INTEGRATION"] = "0"
  Rake::TestTask.new(:_integration) do |t|
    t.libs << "lib"
    t.pattern = "test/test_integration.rb"
  end
  Rake::Task[:_integration].invoke
end

# --- lint / format ---

desc "Run RuboCop linter"
task :lint do
  sh bundle_exec("rubocop --parallel")
end

desc "Run RuboCop and auto-correct offenses"
task :format do
  sh bundle_exec("rubocop --autocorrect-all")
end

# --- build / install ---

desc "Build the rbag gem"
task :build do
  sh "gem build rbag.gemspec"
end

desc "Install rbag locally"
task install: :build do
  gem_file = Dir["rbag-*.gem"].max_by { |f| File.mtime(f) }
  sh "gem install #{gem_file}"
end

task default: :test

def bundle_exec(cmd)
  bundle = "#{RbConfig.ruby} #{Gem.bin_path('bundler', 'bundle')}"
  "#{bundle} exec #{cmd}"
end

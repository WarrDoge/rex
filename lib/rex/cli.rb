# frozen_string_literal: true

require "optparse"

module Rex
  class CLI
    USAGE = "Usage: rex pack [OPTIONS] [DIRECTORY]"

    def initialize(argv)
      @argv = argv.dup
    end

    def run
      subcommand = @argv.shift
      case subcommand
      when "pack"
        run_pack
      when nil, "--help", "-h"
        puts USAGE
        exit 0
      when "--version"
        puts Rex::VERSION
        exit 0
      else
        warn "rex: unknown subcommand '#{subcommand}'"
        warn USAGE
        exit 1
      end
    end

    private

    def run_pack
      options = { entry: nil, output: nil, name: nil, verbose: false }

      parser = OptionParser.new do |o|
        o.banner = USAGE
        o.on("-e", "--entry ENTRY", "Entry point binstub name (default: first file in bin/)") do |v|
          options[:entry] = v
        end
        o.on("-o", "--output FILE", "Output file (default: <name>.rex)") do |v|
          options[:output] = v
        end
        o.on("-n", "--name NAME", "App name (default: directory basename)") do |v|
          options[:name] = v
        end
        o.on("-v", "--verbose", "Stream bundler output") do
          options[:verbose] = true
        end
        o.on("-h", "--help", "Show this help") do
          puts o
          exit 0
        end
      end

      parser.parse!(@argv)
      directory = File.expand_path(@argv.first || Dir.pwd)

      unless Dir.exist?(directory)
        warn "rex: directory not found: #{directory}"
        exit 1
      end

      Packer.new(directory, **options).pack
    end
  end
end

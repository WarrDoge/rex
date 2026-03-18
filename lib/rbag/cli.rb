# frozen_string_literal: true

require "optparse"

module Rbag
  class CLI
    USAGE = "Usage: rbag pack [OPTIONS] [DIRECTORY]"

    def initialize(argv)
      @argv = argv
    end

    def run
      if @argv.empty?
        puts USAGE
        return
      end

      subcommand = @argv.shift
      case subcommand
      when "pack"
        pack_command
      when "-v", "--version"
        puts Rbag::VERSION
      when "-h", "--help"
        puts USAGE
      else
        warn "rbag: unknown subcommand '#{subcommand}'"
        exit 1
      end
    end

    private

    def pack_command
      options = {}
      parser = OptionParser.new do |o|
        o.banner = USAGE
        o.separator ""
        o.separator "Options:"

        o.on("-o", "--output FILE", "Output file (default: <name>.rbag)") do |v|
          options[:output] = v
        end

        o.on("-n", "--name NAME", "Application name") do |v|
          options[:name] = v
        end

        o.on("-e", "--entry SCRIPT", "Entry point script (relative to app root)") do |v|
          options[:entry] = v
        end
      end

      parser.parse!(@argv)
      directory = @argv.shift || Dir.pwd

      unless Dir.exist?(directory)
        warn "rbag: directory not found: #{directory}"
        exit 1
      end

      Packer.new(directory, **options).pack
    end
  end
end

# frozen_string_literal: true

require "rubygems/package"
require "zlib"
require "stringio"
require "fileutils"

module Rbag
  class Archiver
    ALWAYS_EXCLUDE_COMPONENTS = %w[.git .bundle].freeze
    ALWAYS_EXCLUDE_PREFIXES   = %w[vendor/cache].freeze
    FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_DOTMATCH

    def self.create(directory)
      new(directory).create
    end

    def initialize(directory)
      @directory = directory
      @ignore_patterns = load_ignore_patterns
    end

    def create
      io = StringIO.new
      Zlib::GzipWriter.wrap(io) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          collect_entries.each do |entry|
            case entry[:type]
            when :directory
              tar.mkdir(entry[:rel], entry[:mode])
            when :symlink
              tar.add_symlink(entry[:rel], File.readlink(entry[:abs]), entry[:mode])
            else
              tar.add_file_simple(entry[:rel], entry[:mode], entry[:size]) do |tar_io|
                File.open(entry[:abs], "rb") { |f| IO.copy_stream(f, tar_io) }
              end
            end
          end
        end
      end
      io.string
    end

    def files
      collect_entries.reject { |e| e[:type] == :directory }.map { |e| e[:rel] }
    end

    private

    def collect_entries
      result = []
      walk(@directory, "", result)
      result.sort_by! { |e| e[:rel] }
    end

    def walk(abs_dir, rel_prefix, result)
      Dir.entries(abs_dir).each do |name|
        next if [".", ".."].include?(name)

        abs = File.join(abs_dir, name)
        rel = rel_prefix.empty? ? name : File.join(rel_prefix, name)

        next if excluded?(rel)

        stat = File.lstat(abs)
        type = if stat.symlink? then :symlink
               elsif stat.directory? then :directory
               else :file
               end

        result << { rel: rel, abs: abs, mode: stat.mode, type: type, size: stat.size }

        walk(abs, rel, result) if type == :directory
      end
    end

    def load_ignore_patterns
      path = File.join(@directory, ".rbagignore")
      return [] unless File.exist?(path)

      File.readlines(path, chomp: true).reject { |l| l.strip.empty? || l.start_with?("#") }
    end

    def excluded?(rel_path)
      parts = rel_path.split("/")

      return true if parts.any? { |p| ALWAYS_EXCLUDE_COMPONENTS.include?(p) }
      return true if ALWAYS_EXCLUDE_PREFIXES.any? { |prefix| rel_path == prefix || rel_path.start_with?("#{prefix}/") }
      return true if File.basename(rel_path).end_with?(".rbag")

      @ignore_patterns.any? do |pattern|
        if pattern.end_with?("/")
          dir_pat = pattern.chomp("/")
          File.fnmatch?(dir_pat, rel_path, FNMATCH_FLAGS) ||
            rel_path.start_with?("#{dir_pat}/")
        else
          File.fnmatch?(pattern, rel_path, FNMATCH_FLAGS)
        end
      end
    end
  end
end

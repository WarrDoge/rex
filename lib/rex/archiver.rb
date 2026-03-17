# frozen_string_literal: true

require "rubygems/package"
require "zlib"
require "stringio"
require "fileutils"

module Rex
  class Archiver
    ALWAYS_EXCLUDE_COMPONENTS = %w[.git .bundle].freeze
    ALWAYS_EXCLUDE_PREFIXES   = %w[vendor/cache].freeze
    FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_DOTMATCH

    def self.create(directory)
      new(directory).create
    end

    def initialize(directory)
      @directory       = directory
      @ignore_patterns = load_ignore_patterns
    end

    # Returns gzipped tar bytes as a binary String
    def create
      gz_out = StringIO.new
      Zlib::GzipWriter.wrap(gz_out) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          walk(@directory, "", tar)
        end
      end
      gz_out.string
    end

    private

    def load_ignore_patterns
      path = File.join(@directory, ".rexignore")
      return [] unless File.exist?(path)

      File.readlines(path, chomp: true)
          .reject { |l| l.strip.empty? || l.start_with?("#") }
    end

    def walk(abs_dir, rel_prefix, tar)
      entries = Dir.children(abs_dir).sort
      entries.each do |name|
        abs = File.join(abs_dir, name)
        rel = rel_prefix.empty? ? name : "#{rel_prefix}/#{name}"

        next if excluded?(rel)

        stat = File.lstat(abs)

        if stat.symlink?
          target = File.readlink(abs)
          tar.add_symlink(rel, target, stat.mode)
        elsif stat.directory?
          tar.mkdir(rel, stat.mode)
          walk(abs, rel, tar)
        else
          tar.add_file_simple(rel, stat.mode, stat.size) do |io|
            File.open(abs, "rb") { |f| IO.copy_stream(f, io) }
          end
        end
      end
    end

    def excluded?(rel_path)
      parts = rel_path.split("/")

      return true if parts.any? { |p| ALWAYS_EXCLUDE_COMPONENTS.include?(p) }
      return true if ALWAYS_EXCLUDE_PREFIXES.any? { |prefix| rel_path == prefix || rel_path.start_with?("#{prefix}/") }
      return true if File.basename(rel_path).end_with?(".rex")

      @ignore_patterns.any? do |pattern|
        if pattern.end_with?("/")
          dir_pat = pattern.chomp("/")
          File.fnmatch(dir_pat, rel_path, FNMATCH_FLAGS) ||
            rel_path.start_with?("#{dir_pat}/")
        else
          File.fnmatch(pattern, rel_path, FNMATCH_FLAGS)
        end
      end
    end
  end
end

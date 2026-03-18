# frozen_string_literal: true

require "fileutils"
require "pathname"
require "bundler"
require "rbconfig"

module Rbag
  class Packer
    def initialize(directory, name: nil, entry: nil, output: nil)
      @directory = File.expand_path(directory)
      @name      = name || File.basename(@directory)
      @entry     = entry || @name
      @output    = output || File.join(Dir.pwd, "#{@name}.rbag")
    end

    def pack
      validate!
      log "Packing #{@name}..."

      # 1. Create temporary directory
      Dir.mktmpdir("rbag-pack-") do |tmpdir|
        # 2. Bundle install --standalone
        bundle_standalone(tmpdir)

        # 3. Copy app files
        copy_app_files(tmpdir)

        # 4. Create archive
        archive_bytes = Archiver.create(tmpdir)

        # 5. Render stub
        rbag_content = Stub.render(
          archive_bytes: archive_bytes,
          app_name: @name,
          entry: @entry
        )

        File.write(@output, rbag_content)
        FileUtils.chmod(0o755, @output)
      end

      log "Created #{@output}"
    end

    private

    def validate!
      return if Dir.exist?(@directory)

      raise "Directory not found: #{@directory}"
    end

    def bundle_standalone(tmpdir)
      gemfile = File.join(@directory, "Gemfile")
      return unless File.exist?(gemfile)

      log "Installing dependencies..."
      bundle_dir = File.join(tmpdir, "vendor/bundle")
      FileUtils.mkdir_p(bundle_dir)

      # Copy Gemfile and Gemfile.lock
      FileUtils.cp(gemfile, tmpdir)
      lockfile = File.join(@directory, "Gemfile.lock")
      FileUtils.cp(lockfile, tmpdir) if File.exist?(lockfile)

      # Run bundle install
      bundle_path = Gem.bin_path("bundler", "bundle")
      Bundler.with_unbundled_env do
        system(
          { "BUNDLE_GEMFILE" => File.join(tmpdir, "Gemfile") },
          "#{RbConfig.ruby} #{bundle_path} config set --local path 'vendor/bundle' && " \
          "#{RbConfig.ruby} #{bundle_path} config set --local bin 'bin/stubs' && " \
          "#{RbConfig.ruby} #{bundle_path} config set --local without 'development test' && " \
          "#{RbConfig.ruby} #{bundle_path} install && " \
          "#{RbConfig.ruby} #{bundle_path} binstubs --all",
          chdir: tmpdir,
          out: File::NULL
        )
      end
    end

    def copy_app_files(tmpdir)
      archiver = Archiver.new(@directory)
      archiver.files.each do |rel_path|
        dest = File.join(tmpdir, rel_path)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(File.join(@directory, rel_path), dest)
      end
    end

    def log(msg)
      $stdout.puts "[rbag] #{msg}"
    end
  end
end

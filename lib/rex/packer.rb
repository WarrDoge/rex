# frozen_string_literal: true

require "open3"
require "fileutils"
require "rbconfig"

module Rex
  class Packer
    BUNDLER_STEP_ARGS = [
      %w[install --deployment --without development test],
      %w[cache --all --all-platforms],
      %w[binstubs --all --standalone]
    ].freeze

    def initialize(directory, entry: nil, output: nil, name: nil, verbose: false)
      @directory = directory
      @name      = name   || File.basename(directory)
      @output    = output || File.join(Dir.pwd, "#{@name}.rex")
      @entry     = entry
      @verbose   = verbose
    end

    def pack
      log "Packing #{@name} from #{@directory}"

      run_bundler_steps
      resolve_entry!

      log "Archiving..."
      archive_bytes = Archiver.create(@directory)
      log "Archive: #{archive_bytes.bytesize} bytes (compressed)"

      rex_content = Stub.render(
        archive_bytes: archive_bytes,
        app_name: @name,
        entry: @entry
      )

      File.write(@output, rex_content)
      File.chmod(0o755, @output)
      log "Created #{@output}"
    end

    private

    def bundle_bin
      @bundle_bin ||= Gem.bin_path("bundler", "bundle")
    rescue Gem::GemNotFoundException
      raise "Bundler not found. Please install it with: gem install bundler"
    end

    def run_bundler_steps
      # Always set path first so any install step uses the local vendor/bundle
      log "Running: bundle config set path vendor/bundle"
      run_command!([RbConfig.ruby, bundle_bin, "config", "set", "path", "vendor/bundle"])

      ensure_lockfile!

      BUNDLER_STEP_ARGS.each do |args|
        cmd = [RbConfig.ruby, bundle_bin, *args]
        log "Running: bundle #{args.join(' ')}"
        run_command!(cmd)
      end
    end

    def ensure_lockfile!
      lockfile = File.join(@directory, "Gemfile.lock")
      return if File.exist?(lockfile)

      log "No Gemfile.lock found — running bundle install to generate one"
      run_command!([RbConfig.ruby, bundle_bin, "install"])
    end

    def run_command!(cmd)
      Open3.popen2e(*cmd, chdir: @directory) do |_stdin, out_err, wait_thr|
        out_err.each_line { |line| $stdout.print(line) if @verbose }
        status = wait_thr.value
        raise "Command failed (exit #{status.exitstatus}): #{cmd.join(' ')}" unless status.success?
      end
    end

    def resolve_entry!
      return if @entry

      bin_dir = File.join(@directory, "bin")
      raise "No bin/ directory found in #{@directory}. Use -e to specify entry point." unless Dir.exist?(bin_dir)

      candidates = Dir.children(bin_dir)
                      .sort
                      .select { |f| File.file?(File.join(bin_dir, f)) }

      raise "No files found in bin/. Use -e to specify entry point." if candidates.empty?

      @entry = candidates.first
      log "Entry point: bin/#{@entry}"
    end

    def log(msg)
      $stdout.puts "[rex] #{msg}"
    end
  end
end

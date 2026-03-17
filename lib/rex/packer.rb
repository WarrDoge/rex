# frozen_string_literal: true

require "bundler"
require "open3"
require "fileutils"
require "rbconfig"

module Rex
  class Packer
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
      run_bundler_command!(%w[config set path vendor/bundle])
      run_bundler_command!(%w[config set deployment true])
      run_bundler_command!(%w[config set without development:test])

      ensure_lockfile!

      run_bundler_command!(%w[install])
      run_bundler_command!(%w[config set cache_all true])
      run_bundler_command!(%w[config set cache_all_platforms true])
      run_bundler_command!(%w[cache])
      run_bundler_command!(%w[binstubs --all --standalone])
    end

    def ensure_lockfile!
      lockfile = File.join(@directory, "Gemfile.lock")
      return if File.exist?(lockfile)

      log "No Gemfile.lock found — running bundle install to generate one"
      run_bundler_command!(%w[install])
    end

    def run_bundler_command!(args)
      cmd = [RbConfig.ruby, bundle_bin, *args]
      log "Running: bundle #{args.join(' ')}"
      Bundler.with_unbundled_env { run_command!(cmd) }
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

# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"

# Integration tests that run a full pack+execute cycle.
# These are slow (network + bundler) and skipped if SKIP_INTEGRATION=1.
class TestIntegration < Minitest::Test
  def setup
    skip "Set SKIP_INTEGRATION=0 to run integration tests" if ENV.fetch("SKIP_INTEGRATION", "1") == "1"
    @tmpdir = Dir.mktmpdir("rex-integration-")
    build_test_app
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
    # Clean up extracted tmp dirs from this test run
    Dir.glob("/tmp/rex-rextest-*").each { |d| FileUtils.rm_rf(d) }
  end

  def test_packs_and_executes
    out_rex = File.join(@tmpdir, "rextest.rex")
    Rex::Packer.new(app_dir, name: "rextest", entry: "hello", output: out_rex).pack

    assert_path_exists out_rex, "expected .rex file to be created"
    assert File.executable?(out_rex), "expected .rex file to be executable"

    output = `#{RbConfig.ruby} #{out_rex} --hello world 2>&1`.chomp
    result = JSON.parse(output)

    assert result["ok"]
    assert_equal ["--hello", "world"], result["args"]
  end

  def test_second_run_skips_extraction
    out_rex = File.join(@tmpdir, "rextest.rex")
    Rex::Packer.new(app_dir, name: "rextest", entry: "hello", output: out_rex).pack

    # First run: extracts
    system(RbConfig.ruby, out_rex, out: File::NULL, err: File::NULL)

    # Second run: should be fast (no extraction)
    elapsed = Benchmark.realtime { system(RbConfig.ruby, out_rex, out: File::NULL, err: File::NULL) }

    assert_operator elapsed, :<, 5.0, "second run took #{elapsed.round(2)}s — expected < 5s"
  end

  def test_argv_forwarding
    out_rex = File.join(@tmpdir, "rextest.rex")
    Rex::Packer.new(app_dir, name: "rextest", entry: "hello", output: out_rex).pack

    output, = Open3.capture2(RbConfig.ruby, out_rex, "foo", "bar baz")
    result = JSON.parse(output)

    assert_equal ["foo", "bar baz"], result["args"]
  end

  def test_rex_file_has_shebang
    out_rex = File.join(@tmpdir, "rextest.rex")
    Rex::Packer.new(app_dir, name: "rextest", entry: "hello", output: out_rex).pack

    first_line = File.open(out_rex, &:readline).chomp

    assert_equal "#!/usr/bin/env ruby", first_line
  end

  private

  def app_dir
    File.join(@tmpdir, "testapp")
  end

  def build_test_app
    bin_dir = File.join(app_dir, "bin")
    FileUtils.mkdir_p(bin_dir)

    File.write(File.join(app_dir, "Gemfile"), <<~GEMFILE)
      source "https://rubygems.org"
      gem "json"
    GEMFILE

    File.write(File.join(bin_dir, "hello"), <<~RUBY)
      #!/usr/bin/env ruby
      require "json"
      puts JSON.generate({ ok: true, args: ARGV })
    RUBY
    File.chmod(0o755, File.join(bin_dir, "hello"))
  end
end

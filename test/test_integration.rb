# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"

# Integration tests that run a full pack+execute cycle.
# These are slow (network + bundler) and skipped if SKIP_INTEGRATION=1.
class TestIntegration < Minitest::Test
  def setup
    skip "Set SKIP_INTEGRATION=0 to run integration tests" if ENV.fetch("SKIP_INTEGRATION", "1") == "1"
    @tmpdir = Dir.mktmpdir("rbag-integration-")
    build_test_app
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
    # Clean up extracted tmp dirs from this test run
    Dir.glob("/tmp/rbag-rbagtest-*").each { |d| FileUtils.rm_rf(d) }
  end

  def test_packs_and_executes
    out_rbag = File.join(@tmpdir, "rbagtest.rbag")
    Rbag::Packer.new(app_dir, name: "rbagtest", entry: "hello", output: out_rbag).pack

    assert_path_exists out_rbag, "expected .rbag file to be created"
    assert File.executable?(out_rbag), "expected .rbag file to be executable"

    output = `#{RbConfig.ruby} #{out_rbag} --hello world 2>&1`.chomp
    result = JSON.parse(output)

    assert result["ok"]
    assert_equal ["--hello", "world"], result["args"]
  end

  def test_second_run_skips_extraction
    out_rbag = File.join(@tmpdir, "rbagtest.rbag")
    Rbag::Packer.new(app_dir, name: "rbagtest", entry: "hello", output: out_rbag).pack

    # First run: extracts
    system(RbConfig.ruby, out_rbag, out: File::NULL, err: File::NULL)

    # Second run: should be fast (no extraction)
    elapsed = Benchmark.realtime { system(RbConfig.ruby, out_rbag, out: File::NULL, err: File::NULL) }

    assert_operator elapsed, :<, 5.0, "second run took #{elapsed.round(2)}s — expected < 5s"
  end

  def test_argv_forwarding
    out_rbag = File.join(@tmpdir, "rbagtest.rbag")
    Rbag::Packer.new(app_dir, name: "rbagtest", entry: "hello", output: out_rbag).pack

    output, = Open3.capture2(RbConfig.ruby, out_rbag, "foo", "bar baz")
    result = JSON.parse(output)

    assert_equal ["foo", "bar baz"], result["args"]
  end

  def test_rbag_file_has_shebang
    out_rbag = File.join(@tmpdir, "rbagtest.rbag")
    Rbag::Packer.new(app_dir, name: "rbagtest", entry: "hello", output: out_rbag).pack

    first_line = File.open(out_rbag, &:readline).chomp

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

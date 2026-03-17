# frozen_string_literal: true

require_relative "test_helper"

class TestStub < Minitest::Test
  def setup
    @archive_bytes = "fake archive bytes"
    @script = Rex::Stub.render(archive_bytes: @archive_bytes, app_name: "myapp", entry: "myapp")
  end

  def test_has_shebang
    assert @script.start_with?("#!/usr/bin/env ruby\n")
  end

  def test_contains_base64_blob
    require "base64"
    encoded = Base64.encode64(@archive_bytes).chomp

    assert_includes @script, encoded
  end

  def test_tmp_dir_uses_sha256_checksum
    require "digest"
    checksum = Digest::SHA256.hexdigest(@archive_bytes)[0, 16]

    assert_includes @script, "rex-myapp-#{checksum}"
    assert_includes @script, "Dir.tmpdir"
  end

  def test_entry_path_contains_entry_name
    assert_includes @script, "\"bin\", \"myapp\""
  end

  def test_uses_single_quoted_heredoc_for_blob
    # Single-quoted delimiter prevents #{} interpolation inside base64 content
    assert_match(/<<~'BASE64'/, @script)
  end

  def test_requires_stdlib_only
    %w[base64 zlib rubygems/package fileutils stringio rbconfig tmpdir].each do |lib|
      assert_includes @script, "require \"#{lib}\""
    end
  end

  def test_different_archives_produce_different_checksums
    script2 = Rex::Stub.render(archive_bytes: "different bytes", app_name: "myapp", entry: "myapp")
    # Extract TMP_DIR constant from each script
    dir1 = @script[/File\.join\(Dir\.tmpdir,\s*"([^"]+)"\)/, 1]
    dir2 = script2[/File\.join\(Dir\.tmpdir,\s*"([^"]+)"\)/, 1]

    refute_equal dir1, dir2
  end

  def test_app_name_in_tmp_dir
    script = Rex::Stub.render(archive_bytes: "bytes", app_name: "coolapp", entry: "coolapp")

    assert_includes script, "rex-coolapp-"
  end

  def test_cleans_up_on_extraction_failure
    assert_includes @script, "FileUtils.rm_rf(TMP_DIR)"
    assert_includes @script, "abort"
  end

  def test_execs_ruby_with_argv
    assert_includes @script, "exec(RbConfig.ruby, ENTRY_PATH, *ARGV)"
  end

  def test_frozen_string_literal
    assert_includes @script, "# frozen_string_literal: true"
  end

  def test_symlink_fallback_on_windows
    # Stub must rescue symlink creation failures and defer to file copy
    assert_includes @script, "deferred_symlinks"
    assert_includes @script, "NotImplementedError"
    assert_includes @script, "Errno::EPERM"
    assert_includes @script, "File.expand_path"
    assert_includes @script, "FileUtils.cp"
  end
end

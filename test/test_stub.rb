# frozen_string_literal: true

require "test_helper"

class TestStub < Minitest::Test
  def setup
    @archive_bytes = "dummy archive"
    @script = Rbag::Stub.render(archive_bytes: @archive_bytes, app_name: "myapp", entry: "myapp")
  end

  def test_renders_shebang
    assert_match(%r{^#!/usr/bin/env ruby}, @script)
  end

  def test_includes_archive_bytes
    assert_includes @script, @archive_bytes.inspect
  end

  def test_includes_app_name
    assert_includes @script, "myapp".inspect
  end

  def test_includes_extraction_directory
    checksum = Digest::SHA256.hexdigest(@archive_bytes)[0..11]

    assert_includes @script, "rbag-myapp-#{checksum}"
  end

  def test_defines_rbag_stub_module
    assert_includes @script, "module RbagStub"
  end

  def test_calls_rbag_stub_run
    assert_includes @script, "RbagStub.run("
  end

  def test_is_deterministic
    script1 = Rbag::Stub.render(archive_bytes: "bytes", app_name: "myapp", entry: "myapp")
    script2 = Rbag::Stub.render(archive_bytes: "bytes", app_name: "myapp", entry: "myapp")

    assert_equal script1, script2
  end

  def test_output_changes_with_archive_bytes
    script1 = Rbag::Stub.render(archive_bytes: "bytes", app_name: "myapp", entry: "myapp")
    script2 = Rbag::Stub.render(archive_bytes: "different bytes", app_name: "myapp", entry: "myapp")

    refute_equal script1, script2
  end

  def test_extraction_dir_contains_checksum
    script = Rbag::Stub.render(archive_bytes: "bytes", app_name: "coolapp", entry: "coolapp")

    assert_includes script, "rbag-coolapp-"
  end
end

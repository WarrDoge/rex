# frozen_string_literal: true

require_relative "test_helper"
require "rubygems/package"
require "zlib"
require "stringio"

class TestArchiver < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("rex-archiver-test-")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- exclusion logic ---

  def test_excludes_git_directory
    assert excluded?(".git")
    assert excluded?(".git/config")
    assert excluded?("sub/.git/config")
  end

  def test_excludes_bundle_directory
    assert excluded?(".bundle")
    assert excluded?(".bundle/config")
  end

  def test_excludes_vendor_cache
    assert excluded?("vendor/cache")
    assert excluded?("vendor/cache/json-2.0.gem")
  end

  def test_does_not_exclude_vendor_bundle
    refute excluded?("vendor/bundle")
    refute excluded?("vendor/bundle/ruby/3.2.0/gems/json-2.0/lib/json.rb")
  end

  def test_excludes_rex_files
    assert excluded?("myapp.rex")
    assert excluded?("dist/myapp.rex")
  end

  def test_does_not_exclude_normal_files
    refute excluded?("lib/app.rb")
    refute excluded?("bin/myapp")
    refute excluded?("Gemfile")
  end

  def test_rexignore_pattern
    write_file(".rexignore", "spec/\ntest/\n*.md\n")

    assert excluded?("spec/foo_spec.rb")
    assert excluded?("test/foo_test.rb")
    assert excluded?("README.md")
    refute excluded?("lib/app.rb")
  end

  def test_rexignore_ignores_comments_and_blank_lines
    write_file(".rexignore", "# comment\n\nspec/\n")

    assert excluded?("spec/foo.rb")
    refute excluded?("lib/app.rb")
  end

  # --- archive creation ---

  def test_creates_valid_gzip
    write_file("lib/app.rb", "puts 'hello'")
    bytes = Rex::Archiver.create(@tmpdir)

    assert_predicate bytes.bytesize, :positive?
    # Should decompress without error
    Zlib::GzipReader.wrap(StringIO.new(bytes), &:read)
  end

  def test_archive_contains_expected_files
    write_file("lib/app.rb", "puts 'hello'")
    write_file("bin/myapp", "#!/usr/bin/env ruby")

    entries = tar_entries(Rex::Archiver.create(@tmpdir))

    assert_includes entries, "lib/app.rb"
    assert_includes entries, "bin/myapp"
  end

  def test_archive_excludes_git
    write_file(".git/config", "[core]")
    write_file("lib/app.rb", "")

    entries = tar_entries(Rex::Archiver.create(@tmpdir))

    refute(entries.any? { |e| e.start_with?(".git") })
    assert_includes entries, "lib/app.rb"
  end

  def test_archive_handles_symlinks
    write_file("lib/real.rb", "# real")
    File.symlink(File.join(@tmpdir, "lib/real.rb"), File.join(@tmpdir, "lib/link.rb"))

    bytes = Rex::Archiver.create(@tmpdir)
    entries = tar_entries_with_type(bytes)

    symlink_entry = entries.find { |name, _| name == "lib/link.rb" }

    assert symlink_entry, "expected symlink entry in archive"
    assert_equal "2", symlink_entry[1], "expected typeflag 2 (symlink)"
  end

  def test_archive_preserves_file_permissions
    write_file("bin/myapp", "#!/usr/bin/env ruby")
    File.chmod(0o755, File.join(@tmpdir, "bin/myapp"))

    bytes = Rex::Archiver.create(@tmpdir)
    Zlib::GzipReader.wrap(StringIO.new(bytes)) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each do |entry|
          assert_equal 0o755, entry.header.mode & 0o777 if entry.header.name == "bin/myapp"
        end
      end
    end
  end

  def test_archive_is_deterministic
    write_file("lib/a.rb", "a")
    write_file("lib/b.rb", "b")
    bytes1 = Rex::Archiver.create(@tmpdir)
    bytes2 = Rex::Archiver.create(@tmpdir)
    # Same directory → same tar content (entries in sorted order)
    assert_equal tar_entries(bytes1), tar_entries(bytes2)
  end

  private

  def excluded?(rel_path)
    Rex::Archiver.new(@tmpdir).send(:excluded?, rel_path)
  end

  def write_file(rel_path, content)
    abs = File.join(@tmpdir, rel_path)
    FileUtils.mkdir_p(File.dirname(abs))
    File.write(abs, content)
  end

  def tar_entries(gz_bytes)
    names = []
    Zlib::GzipReader.wrap(StringIO.new(gz_bytes)) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each { |e| names << e.header.name }
      end
    end
    names
  end

  def tar_entries_with_type(gz_bytes)
    entries = []
    Zlib::GzipReader.wrap(StringIO.new(gz_bytes)) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each { |e| entries << [e.header.name, e.header.typeflag] }
      end
    end
    entries
  end
end

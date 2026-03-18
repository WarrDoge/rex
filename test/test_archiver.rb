# frozen_string_literal: true

require "test_helper"

class TestArchiver < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("rbag-archiver-test-")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_lists_files_recursively
    write_file("hello.rb", "puts 'hello'")
    write_file("subdir/world.rb", "puts 'world'")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["hello.rb", "subdir/world.rb"].sort, archiver.files.sort
  end

  def test_excludes_git_directory
    write_file(".git/config", "config")
    write_file("app.rb", "app")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["app.rb"], archiver.files
  end

  def test_excludes_bundle_directory
    write_file(".bundle/config", "config")
    write_file("app.rb", "app")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["app.rb"], archiver.files
  end

  def test_excludes_vendor_cache
    write_file("vendor/cache/somegem.gem", "gem")
    write_file("app.rb", "app")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["app.rb"], archiver.files
  end

  def test_excludes_rbag_files
    assert excluded?("myapp.rbag")
    assert excluded?("dist/myapp.rbag")
  end

  def test_respects_rbagignore
    write_file(".rbagignore", "secret.txt")
    write_file("secret.txt", "shhh")
    write_file("app.rb", "app")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["app.rb", ".rbagignore"].sort, archiver.files.sort
  end

  def test_rbagignore_pattern
    write_file(".rbagignore", "spec/\ntest/\n*.md\n")
    write_file("spec/test_spec.rb", "spec")
    write_file("README.md", "readme")
    write_file("app.rb", "app")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["app.rb", ".rbagignore"].sort, archiver.files.sort
  end

  def test_rbagignore_ignores_comments_and_blank_lines
    write_file(".rbagignore", "# comment\n\nspec/\n")
    write_file("spec/test_spec.rb", "spec")
    write_file("app.rb", "app")

    archiver = Rbag::Archiver.new(@tmpdir)

    assert_equal ["app.rb", ".rbagignore"].sort, archiver.files.sort
  end

  def test_create_returns_gzipped_tar
    write_file("hello.rb", "puts 'hello'")
    bytes = Rbag::Archiver.create(@tmpdir)

    # Check for GZIP magic number
    assert_equal "\x1F\x8B".b, bytes[0..1].b
  end

  def test_archive_contains_files
    write_file("hello.rb", "puts 'hello'")
    write_file("lib/world.rb", "puts 'world'")

    entries = tar_entries(Rbag::Archiver.create(@tmpdir))

    assert_includes entries, "hello.rb"
    assert_includes entries, "lib/world.rb"
  end

  def test_archive_preserves_executable_bit
    write_file("run.sh", "echo 'hi'")
    File.chmod(0o755, File.join(@tmpdir, "run.sh"))

    bytes = Rbag::Archiver.create(@tmpdir)
    mode = tar_entry_mode(bytes, "run.sh")

    assert_equal 0o755, mode & 0o777
  end

  def test_archive_entries_are_sorted
    write_file("c.rb", "c")
    write_file("a.rb", "a")
    write_file("b.rb", "b")

    entries = tar_entries(Rbag::Archiver.create(@tmpdir))

    assert_equal entries, entries.sort
  end

  private

  def write_file(path, content)
    full_path = File.join(@tmpdir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  def tar_entries(bytes)
    entries = []
    each_tar_entry(bytes) { |e| entries << e.full_name }
    entries
  end

  def tar_entry_mode(bytes, name)
    each_tar_entry(bytes) do |e|
      return e.header.mode & 0o777 if e.full_name == name
    end
    nil
  end

  def each_tar_entry(bytes, &block)
    Zlib::GzipReader.wrap(StringIO.new(bytes)) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each(&block)
      end
    end
  end

  def excluded?(rel_path)
    Rbag::Archiver.new(@tmpdir).send(:excluded?, rel_path)
  end
end

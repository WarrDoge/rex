# rex

PEX for Ruby. Pack a Ruby application and all its gem dependencies into a single self-executing `.rex` file.

## How it works

`rex pack` vendors your gems with Bundler, creates standalone binstubs (no Bundler required at runtime), archives the whole thing as a gzipped tar, and embeds it into a Ruby script. The output is a single `.rex` file that self-extracts to `/tmp/` on first run and then executes your app directly.

```
myapp/                         →    myapp.rex
  Gemfile                           (598 KB, single file)
  bin/myapp
  lib/
  vendor/bundle/
```

The target host only needs Ruby — no Bundler, no gems.

## Installation

```sh
gem install rex
```

Or from source:

```sh
git clone https://github.com/WarrDoge/rex
cd rex
rake install
```

## Usage

```sh
# Pack the app in the current directory
rex pack

# Pack a specific directory
rex pack ./myapp

# Specify options explicitly
rex pack -n myapp -e myapp -o dist/myapp.rex ./myapp
```

### Options

```
-e, --entry ENTRY    Entry point binstub name (default: first file in bin/)
-o, --output FILE    Output file (default: <name>.rex in cwd)
-n, --name NAME      App name (default: directory basename)
-v, --verbose        Stream bundler output
```

## Running the output

```sh
# With explicit interpreter
ruby myapp.rex

# As an executable (uses #!/usr/bin/env ruby shebang)
chmod +x myapp.rex
./myapp.rex

# Pass arguments normally
./myapp.rex --config prod.yml serve
```

On the first run, the app extracts to `/tmp/rex-<name>-<checksum>/`. Subsequent runs skip extraction and start in ~150ms.

## Pack sequence

1. `bundle config set path vendor/bundle`
2. `bundle install --deployment` (generates `Gemfile.lock` first if absent)
3. `bundle cache --all --all-platforms`
4. `bundle binstubs --all --standalone`
5. Archive app directory as tar.gz (excludes `.git/`, `vendor/cache/`, `*.rex`)
6. Embed archive as base64 in a self-extracting Ruby script

## Excluding files

Create a `.rexignore` file in your app root. Same format as `.gitignore` (one fnmatch pattern per line):

```
spec/
test/
.rspec
*.md
log/
tmp/
.env
```

The following are always excluded regardless of `.rexignore`: `.git/`, `.bundle/`, `vendor/cache/`, `*.rex`.

## Requirements

- Ruby >= 3.0 (packer side)
- Bundler (packer side)
- Ruby >= 3.0 (target host, any platform)

## License

MIT

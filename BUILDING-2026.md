# Building the Ceylon Website (2026)

The site uses [Awestruct](http://awestruct.org/) 0.5.5, a Ruby-based static site
generator from ~2014. Modern Ruby and compilers break several of its gem
dependencies, so we build inside a Docker container with Ruby 2.6 installed via
rbenv.

## Prerequisites

- Docker
- [just](https://github.com/casey/just) (optional, for quick-start commands)
- Python 3 (optional, for serving the built site from the host)

## Quick start

```bash
just docker-build   # build the Docker image (one time)
just dev            # run the dev server with auto-regeneration and livereload
```

Then open http://localhost:4242.

Other commands:

```bash
just build          # generate the static site only
just clean          # remove generated site and caches
just serve          # serve the built _site/ from the host using python3
just                # list all available commands
```

## Manual build steps

### Build the Docker image

```bash
docker build -t ceylon-site .
```

This creates a Debian trixie-slim image with Ruby 2.6.10 (via rbenv) and all
native build dependencies. The Ruby version is pinned to 2.6 because the
Gemfile's nokogiri (~> 1.5.10) and rdiscount (~> 2.0.7) have C extensions
incompatible with Ruby 2.7+.

## Start the container

```bash
docker run -it --rm -v "$(pwd):/site" -p 4242:4242 ceylon-site
```

## Generate and serve the site

Gems are pre-installed in the Docker image, so you can start using awestruct
immediately.

### Development server (with auto-regeneration and livereload)

Inside the container:

```bash
RUBYOPT="-r/site/_ext/force_polling.rb" bundle exec awestruct -d
```

This builds the site, starts a preview server at http://localhost:4242, watches
for file changes, and auto-regenerates. The `RUBYOPT` prefix forces the listen
gem to use polling, which is required for Docker bind mounts. Livereload is
provided via guard-livereload.

### Static site generation only

Inside the container:

```bash
bundle exec awestruct -g
```

The output goes to `_site/`.

### Serve the built site from the host

If you've already generated the site and just want to serve it without the
container running:

```bash
cd _site
python3 -m http.server 4242
```

Then open http://localhost:4242.

## Rebuilding gems

If you change the Gemfile or need to reinstall gems from scratch inside the
container:

```bash
bundle config force_ruby_platform true
bundle config build.nokogiri --with-cflags="-Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=int-conversion"
bundle config build.rdiscount --with-cflags="-Wno-error=implicit-function-declaration"
bundle install
```

- `force_ruby_platform true` — prevents Bundler from downloading precompiled
  native gems that target Ruby 3.x.
- The `--with-cflags` settings work around GCC 14 treating various C warnings
  as errors in the old nokogiri and rdiscount native extensions.

## File watching in Docker

The listen gem's inotify adapter doesn't receive events through Docker bind
mounts. The `_ext/force_polling.rb` monkey-patch forces listen to use its
polling adapter instead. The justfile passes this via
`RUBYOPT="-r/site/_ext/force_polling.rb"` on awestruct commands so it doesn't
affect other Ruby processes in the container.

## Gemfile notes

- `celluloid` is pinned to `~> 0.16.0`. Listen 2.7.x (a dependency of
  awestruct) was built against celluloid 0.16's supervision API. Celluloid
  0.17+ changed the `SupervisionGroup#add` method signature, causing the
  file watcher to crash and take down the dev server. Celluloid 0.18+ removed
  `celluloid/logger` entirely, which listen also requires.

# List available commands
default:
    @just --list

image := "ceylon-site"
port := "4242"
rubyopt := '-e RUBYOPT="-r/site/_ext/force_polling.rb"'
docker-run := "docker run --rm -v $(pwd):/site"

# Build the Docker image
docker-build:
    docker build -t {{image}} .

# Generate the static site
build:
    {{docker-run}} {{rubyopt}} {{image}} bundle exec awestruct -g

# Run the development server with auto-regeneration and livereload
dev:
    {{docker-run}} -p {{port}}:{{port}} -it {{rubyopt}} {{image}} bundle exec awestruct -d

# Remove generated site
clean:
    rm -rf _site .awestruct .sass-cache

# Serve the built site from _site/ using Python
serve:
    cd _site && python3 -m http.server {{port}}

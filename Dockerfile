FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo iptables iproute2 zip unzip curl ca-certificates \
    git vim tmux lsof dnsutils bash-completion zsh \
    build-essential gcc zlib1g-dev gh jq fzf less procps gnupg2 \
    openssh-client iputils-ping rsync file wget \
    ripgrep fd-find bat tree just bc gawk \
    tzdata locales \
    libreadline8t64 libreadline-dev libssl-dev libffi-dev libyaml-dev \
    libxml2-dev libxslt1-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

RUN git clone https://github.com/rbenv/rbenv.git $RBENV_ROOT \
    && git clone https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build \
    && rbenv install 2.6.10 \
    && rbenv global 2.6.10 \
    && gem install bundler -v 1.17.3

WORKDIR /site

COPY Gemfile Gemfile.lock ./
RUN bundle config force_ruby_platform true \
    && bundle config build.nokogiri --with-cflags="-Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=int-conversion" \
    && bundle config build.rdiscount --with-cflags="-Wno-error=implicit-function-declaration" \
    && bundle install

CMD ["bash"]

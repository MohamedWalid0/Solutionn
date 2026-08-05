ARG RUBY_VERSION=3.3.5
FROM ruby:${RUBY_VERSION}-slim

# Install system dependencies needed to build native gem extensions (pg, etc.)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    libvips \
    git \
    curl \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# This environment's Docker network has no IPv6 route, but rubygems.org
# (and other hosts) resolve to IPv6 first, causing bundler/gem to hang
# until the IPv6 attempt times out. Prefer IPv4 so lookups connect immediately.
RUN echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf

# Run as a non-root user matching the host UID/GID so files created inside
# the container (via the bind mount) stay owned by the host user, not root.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

WORKDIR /rails

# Install gems first for better layer caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# Entrypoint clears any stale server pid left over from a previous run
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

RUN chown -R rails:rails /rails /usr/local/bundle
USER rails:rails

ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

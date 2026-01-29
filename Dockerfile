# Production Dockerfile - Multi-stage build
FROM elixir:1.17.3-otp-26-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base nodejs npm git

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Build assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

COPY priv priv
COPY assets assets
RUN mix assets.deploy

# Compile and build release
COPY lib lib
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Create release
RUN mix release

# Start a new build stage for the runtime
FROM alpine:3.18 AS runtime

RUN apk add --no-cache openssl ncurses-libs libstdc++ libgcc

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/youtube_video_chat_app ./

ENV HOME=/app

EXPOSE 4000

CMD ["bin/youtube_video_chat_app", "start"]

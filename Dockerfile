# Build stage
FROM elixir:1.20.3-otp-28-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends zip ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && mix deps.compile

COPY . .

# Kit zips are gitignored and generated on demand; build them inside the image
RUN sh scripts/build_kit.sh

RUN mix compile && mix release

# Runtime stage
FROM elixir:1.20.3-otp-28-slim

WORKDIR /app

ENV MIX_ENV=prod

COPY --from=build /app/_build/prod/rel/slimes ./

EXPOSE 4000

CMD ["/app/bin/slimes", "start"]

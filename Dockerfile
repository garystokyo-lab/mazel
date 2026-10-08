FROM hexpm/elixir:1.17.3-erlang-25.3.2.12-debian-bookworm-20240926-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app/apps/room
COPY apps/room/mix.exs apps/room/mix.lock* ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get
COPY apps/room ./
ENV PORT=4747 MAZEL_HTTP=1
EXPOSE 4747
CMD ["mix", "run", "--no-halt"]
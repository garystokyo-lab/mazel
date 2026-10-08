import Config

config :room,
  port: String.to_integer(System.get_env("PORT") || "4747")

# Display-only. Protocol ids stay (`badge`, `direct`, `need`). Example:
# config :room, labels: %{badge: "Stamp"}

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

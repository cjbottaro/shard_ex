use Mix.Config

config :shard, Shard.TestRepo,
  adapter: Ecto.Adapters.Postgres,
  hostname: "localhost",
  port: 5432

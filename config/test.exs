use Mix.Config

config :shard, :repo_defaults,
  adapter: Ecto.Adapters.Postgres,
  hostname: "localhost",
  port: 5432

config :shard, :mod, ShardInfo

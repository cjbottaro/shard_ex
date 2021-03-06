# Shard

Use Ecto repositories across multiple databases and servers.

## Quickstart

In your Mix config files somewhere...

```elixir
config :your_app, Repo,
  adapter: Ecto.Adapters.Postgres,
  hostname: "localhost",
  username: "cjbottaro",
  password: "12345"
  port: 5432
```

Then in your code...

```elixir
defmodule Repo do
  use Shard.Repo, otp_app: :your_app
end

Repo.set "database01"
Repo.all(User)

Repo.set "database02"
Repo.all(User)
```

## How it works

Ecto repos are created on demand when `set` is called on a Shard repo. Then the
Shard repo delegates to the Ecto repo corresponding to the shard it's on.

## Runtime config

This is done with a callback, exactly like `Ecto.Repo`.

```elixir
defmodule Repo do
  use Shard.Repo, otp_app: :your_app

  def init(config) do
    config
      |> Keyword.put(:username, System.get("PG_USER"))
      |> Keyword.put(:password, System.get("PG_PASS"))
  end
end
```

## Ecto configuration per shard

This is also done with a callback.

```elixir
defmodule Repo do
  use Shard.Repo, otp_app: :your_app

  def shard_config("database01") do
    config
      |> Keyword.put(:hostname, "foo.company.com")
      |> Keyword.put(:database, "db01")
  end

  def shard_config("database02") do
    config
      |> Keyword.put(:hostname, "bar.company.com")
      |> Keyword.put(:database, "db02")
  end

  def shard_config(shard) do
    config
      |> Keyword.put(:hostname, "db.company.com")
      |> Keyword.put(:database, shard)
  end
end
```

## Cleaning up (closing connections)

Shard keeps track of what Ecto repos are being used by what processes. If a
repo is not being used by any process, then Shard will shut it down.

The repo will be started again when some process tries to use it.

If the `:cooldown` option is set, Shard will keep track of the last time an
Ecto repo was used and only shut it down after `:cooldown` (time in ms).

```elixir
config :my_app, ShardedRepo,
  cooldown: 5000
```

This can be said as, "Wait 5000 ms before shutting down unused Ecto repos."

Using this option can reduce database connection churn.

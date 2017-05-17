# Shard

Use Ecto repositories with multiple databases across multiple servers.

Inspired by Ruby's [Apartment](https://rubygems.org/gems/apartment) and
Elixir's [Apartmentex](https://hex.pm/packages/apartmentex).

## Quickstart

In your Mix config files somewhere...

```elixir
config :shard, defaults: [
  adapter: Ecto.Adapters.Postgres,
  hostname: "localhost",
  username: "cjbottaro",
  password: "12345"
  port: 5432
]
```

Then in your code...

```elixir
Shard.set "database01"
Shard.repo.all(User)

Shard.set "database02"
Shard.repo.all(User)
```

## How it works

`Shard.set` dynamically creates and starts an Ecto repo based on the
`:defaults` from the Mix config. It also associates the current process
to the shard.

`Shard.repo` returns the Ecto repo that is associated with the current process.

## Multiple database servers

You can completely customize the connection parameters for each shard by
specifying a module that returns shard info.

```elixir
config :shard, :mod, MyApp.ShardInfo
```

```elixir
defmodule MyApp.ShardInfo do

  def info("foo") do
    [
      adapter: Ecto.Adapters.MySQL,
      hostname: "host01.company.com",
      database: "foo_db"
    ]
  end

  def info(shard) do
    [
      hostname: "host02.company.com",
      database: "#{shard}_db"
    ]
  end

end
```

Note that the keyword list returned by the functions is merged with the
`:defaults` from the Mix config.

## Cleaning up (closing connections)

Shard keeps track of what Ecto repos are being used by what processes. If a
repo is not being used by any process, then Shard will shut it down. As soon
as a process calls `Shard.set` on a shutdown repo, Shard will automatically
start it up again.

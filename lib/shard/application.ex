defmodule Shard.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # This supervises Ecto repos. The Shard repo should be supervised by the user.
      {DynamicSupervisor, strategy: :one_for_one, name: Shard.Repo.Supervisor}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

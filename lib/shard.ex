defmodule Shard do
  @moduledoc """
  Set shards and retreive Ecto repos for the given shard.

  See the README for more comprehensive usage/documentation.
  """

  @doc """
  You don't really need to call this. A supervised process is started as a part
  of this application's module callback.
  """
  def start_link(options \\ []) do
    Shard.Server.start_link(options)
  end

  @doc """
  Set the shard for the current process.
  """
  def set(pid \\ Shard.Server, shard) do
    GenServer.call(pid, {:set, shard})
  end

  @doc """
  Get the shard for the current process. You don't really need to call this.
  """
  def get(pid \\ Shard.Server) do
    GenServer.call(pid, :get)
  end

  @doc """
  Set the shard only for the duration of the function, then
  set it back to what it previously was.

  ## Example
      Shard.set "db01"
      Shard.use "db02", fn ->
        Shard.get # "db02"
      end
      Shard.get # "db01"
  """
  def use(pid \\ Shard.Server, shard, func) do
    previous = get(pid)
    :ok = set(pid, shard)
    try do
      func.()
    after
      set(pid, previous)
    end
  end

  @doc """
  Get the Ecto repo for the currently set shard.

  ## Example
      Shard.set "db01"
      Shard.repo.get(User, 1)

      Shard.set "db02"
      Shard.repo.get(User, 1)
  """
  #
  def repo(pid \\ Shard.Server) do
    import Shard.Lib, only: [repo_for: 1]

    case get(pid) do
      nil -> raise "shard not set"
      shard -> repo_for(shard)
    end
  end

end

defmodule Shard.TestHelper do

  def reset(pid \\ Shard.Server) do
    GenServer.call(pid, :reset)
  end

  def debug(pid \\ Shard.Server) do
    GenServer.call(pid, :debug)
  end

end

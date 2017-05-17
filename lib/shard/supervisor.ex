defmodule Shard.Supervisor do
  @moduledoc false
  
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(nil) do
    children = [
      worker(Shard.Server, [[], [name: Shard.Server]])
    ]
    supervise(children, strategy: :one_for_one)
  end

end

defmodule Shard.Application do
  @moduledoc false
  
  use Application

  def start(_type, _args) do
    Shard.Supervisor.start_link
  end
end

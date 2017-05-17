defmodule Shard.Info do
  @moduledoc false

  def info(shard) do
    [
      database: shard
    ]
  end

end

defmodule ShardInfo do

  def info(:controller) do
    [
      database: "scholarship_manager_test"
    ]
  end

  def info(client) do
    [
      database: "shard_#{client}_#{Mix.env}_master"
    ]
  end

end

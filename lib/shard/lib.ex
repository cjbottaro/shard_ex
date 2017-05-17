defmodule Shard.Lib do
  @moduledoc false

  def repo_for(shard) do
    Module.concat([Shard, Repo, shard])
  end

  def shutdown_repo_for(shard) do
    shard |> repo_for |> shutdown_repo
  end

  def otp_app_for(shard) do
    "__shard_#{shard}__" |> String.to_atom
  end

  def repo_config_for(shard) do
    config = Application.get_env(:shard, :repo_defaults, [])
    module = Application.get_env(:shard, :mod, Shard.Info)
    Keyword.merge(config, module.info(shard))
  end

  def shutdown_repo(repo) do
    case Process.whereis(repo) do
      nil -> nil
      pid -> repo.stop(pid)
    end
  end

end

require Logger

defmodule Shard.Lib do
  @moduledoc false

  def normalize_shard(shard) do
    case shard do
      nil -> nil
      s when is_binary(s) -> String.trim(shard)
      a when is_atom(a) -> to_string(a) |> normalize_shard()
    end
  end

  def ecto_repo_for(shard_repo, shard) do
    Module.concat([shard_repo, EctoRepos, shard])
  end

  def shutdown_repo_for(shard_repo, shard) do
    ecto_repo_for(shard_repo, shard) |> shutdown_repo
  end

  def ecto_otp_app_for(shard) do
    "__shard_#{shard}__" |> String.to_atom
  end

  def ecto_repo_config_for(shard, repo, config) do
    Keyword.merge(config, repo.shard_config(shard))
  end

  def shutdown_repo(repo) do
    case Process.whereis(repo) do
      nil -> nil
      pid ->
        shard  = Module.split(repo) |> List.last
        Logger.debug "Shutting down repo for shard: #{shard}"
        DynamicSupervisor.terminate_child(Shard.Repo.Supervisor, pid)
    end
  end

end

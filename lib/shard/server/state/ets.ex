defmodule Shard.Server.State.Ets do
  @behaviour Shard.Server.State

  import Shard.Lib, only: [now: 0]

  def init(state) do
    :ets.new(state.repo, [:bag, :public, :named_table])
    state
  end

  def track_shard(state, shard) do
    :ets.insert(state.repo, {:shard, shard})
    state
  end

  def all_shards(state) do
    :ets.match(state.repo, {:shard, :"$1"}) |> Enum.map(&List.first/1)
  end

  def current(pid, state) do
    case :ets.lookup(state.repo, pid) do
      [{_pid, shard} | []] -> shard
      [] -> nil
    end
  end

  def set_current(state, pid, nil) do
    :ets.delete(state.repo, pid)
    state
  end

  def set_current(state, pid, shard) do
    :ets.insert(state.repo, {pid, shard})
    state
  end

  def track_pid(state, pid, shard) do
    :ets.insert(state.repo, {shard, pid})
    state
  end

  def untrack_pid(state, pid, shard) do
    :ets.delete_object(state.repo, {shard, pid})
    state
  end

  def track_last_used(state, shard) do
    if :ets.lookup(state.repo, shard) == [] do
      :ets.insert(state.repo, {:last_used, shard, now()})
    end
    state
  end

  def untrack_last_used(state, shard) do
    :ets.match_delete(state.repo, {:last_used, shard, :"_"})
    state
  end

  def all_unused(state) do
    :ets.match(state.repo, {:last_used, :"$1", :"$2"})
      |> Enum.map(&List.to_tuple/1)
  end

  def debug(state) do
    info = %{
      shards: [],
      current: %{},
      in_use: %{},
      last_used: %{}
    }

    Enum.reduce :ets.match(state.repo, :"$1"), info, fn item, info ->
      item = List.first(item) # Why does ets return single element lists?
      case item do
        {:shard, shard} -> Map.update! info, :shards, fn shards ->
          [shard | shards]
        end
        {pid, shard} when is_pid(pid) -> Map.update! info, :current, fn current ->
          Map.put(current, pid, shard)
        end
        {shard, pid} when is_binary(shard) -> Map.update! info, :in_use, fn pids ->
          Map.update pids, shard, MapSet.new([pid]), fn set ->
            MapSet.put(set, pid)
          end
        end
        {:last_used, shard, timestamp} -> Map.update! info, :last_used, fn last_used ->
          Map.put(last_used, shard, timestamp)
        end
      end
    end
  end

  def reset(state) do
    :ets.delete_all_objects(state.repo)
    state
  end

end

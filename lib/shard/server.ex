defmodule Shard.Server do
  @moduledoc false

  use GenServer

  import Shard.Lib

  # TODO will this waste too many cycles?
  @cooldown_purge_interval 100

  def start_link(options, gen_options) do
    GenServer.start_link(__MODULE__, options, gen_options)
  end

  def init({repo, config}) do
    if config[:cooldown] do
      Process.send_after(self(), :cooldown_purge, @cooldown_purge_interval)
    end

    {
      :ok,
      %{
        repo: repo,
        config: config,

        # %{ pid => shard_name }
        # What shard is this pid currently set to?
        repo_map: %{},

        # %{ shard_name => set_of_pids }
        # Who all is using this shard?
        proc_map: %{},

        # %{ shard_name => timestamp_in_ms }
        # When was this shard last used?
        last_use: %{},
      }
    }
  end

  def handle_call({:set, nil}, {pid, _}, state) do
    {:reply, :ok, unset(state, pid)}
  end

  def handle_call({:set, shard}, {pid, _}, state) do
    case state.repo_map[pid] do
      ^shard -> {:reply, :already_set, state} # Noop, they are already on this shard.
      _ -> do_set(shard, pid, state)
    end
  end

  def handle_call(:get, {pid, _}, state) do
    {:reply, state.repo_map[pid], state}
  end

  # There is no public api for this; it's just used for testing.
  # See test/support/test_helper.ex.
  # Returns the state of the gen server.
  def handle_call(:debug, _from, state) do
    {:reply, state, state}
  end

  # There is no public api for this; it's just used for testing.
  # See test/support/test_helper.ex.
  # Finds all repos and shuts them down.
  def handle_call(:reset, _from, _state) do
    Enum.each :code.all_loaded, fn {module, _} ->
      name = to_string(module)
      if String.starts_with?(name, "Elixir.Shard.Repo.") do
        shutdown_repo(module)
      end
    end
    {:reply, :ok, %{repo_map: %{}, proc_map: %{}}}
  end

  # Monitor processes that have called `set` for going down, then update our
  # internal state, potentially shutting down the repo if nothing else is
  # using it.
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, unset(state, pid)}
  end

  # If cooldown option is set, then wake up periodically to see if we can
  # shutdown any unused Ecto repos.
  def handle_info(:cooldown_purge, state) do
    cooldown = state.config[:cooldown]

    state = Map.update! state, :last_use, fn last_use ->
      Enum.reduce last_use, %{}, fn {shard, time}, last_use ->
        if :os.system_time(:millisecond) - time >= cooldown do
          shutdown_repo_for(state.repo, shard)
          last_use
        else
          Map.put(last_use, shard, time)
        end
      end
    end

    Process.send_after(self(), :cooldown_purge, @cooldown_purge_interval)

    {:noreply, state}
  end

  def do_set(shard, pid, state) do
    Process.monitor(pid)

    ensure_repo_defined(shard, state)

    state = unset(state, pid)
      |> set_proc(shard, pid)
      |> set_repo(shard, pid)
      |> in_use(shard)

    {:reply, :ok, state}
  end

  defp ensure_repo_defined(shard, %{repo: repo, config: config}) do
    ecto_repo = ecto_repo_for(repo, shard)

    if !Code.ensure_loaded?(ecto_repo) do
      ecto_otp_app     = ecto_otp_app_for(shard)
      ecto_repo_config = ecto_repo_config_for(shard, repo, config)

      # Dynamically define the otp_app configuration for the repo.
      # Why? Ecto repos just work that way. Lucky Elixir doesn't
      # complain about us writing configs for dummy/fake otp apps.
      Application.put_env(ecto_otp_app, ecto_repo, ecto_repo_config)

      # Dynamically define the repo module.
      definition = quote do: use Ecto.Repo, otp_app: unquote(ecto_otp_app)
      defmodule ecto_repo, do: Module.eval_quoted(__MODULE__, definition)
    end
  end

  defp set_repo(state, shard, pid) do
    put_in(state, [:repo_map, pid], shard)
  end

  defp rem_repo(state, pid) do
    repo_map = Map.delete(state.repo_map, pid)
    %{ state | repo_map: repo_map }
  end

  defp set_proc(state, shard, pid) do
    Map.update! state, :proc_map, fn proc_map ->
      Map.update proc_map, shard, MapSet.new([pid]), fn pids ->
        MapSet.put(pids, pid)
      end
    end
  end

  defp rem_proc(state, shard, pid) do
    Map.update! state, :proc_map, fn proc_map ->
      Map.update! proc_map, shard, fn pids ->
        MapSet.delete(pids, pid)
      end
    end
  end

  # If a shard is in use, it should not be in the last_use map.
  defp in_use(state, shard) do
    Map.update!(state, :last_use, &Map.delete(&1, shard))
  end

  defp unset(state, pid) do
    if shard = state.repo_map[pid] do
      state |> rem_proc(shard, pid) |> rem_repo(pid) |> prune
    else
      state
    end
  end

  defp prune(state) do
    {unused, proc_map} = state.proc_map
      |> Map.to_list
      |> prune_proc_map

    state = %{state | proc_map: proc_map}

    if state.config[:cooldown] do
      record_last_use(state, unused)
    else
      shutdown_unused(state, unused)
    end
  end

  # Nifty little function to prune proc_map where pids are empty and also
  # return which shards were empty.
  @spec prune_proc_map(list) :: {unused :: list, pruned :: map}
  defp prune_proc_map(proc_map, unused \\ [], pruned \\ %{})
  defp prune_proc_map([], unused, pruned), do: {unused, pruned}
  defp prune_proc_map([{shard, pids} | rest], unused, pruned) do
    if MapSet.size(pids) == 0 do
      prune_proc_map(rest, [shard | unused], pruned)
    else
      prune_proc_map(rest, unused, Map.put(pruned, shard, pids))
    end
  end

  defp record_last_use(state, unused) do
    Map.update! state, :last_use, fn last_use ->
      Enum.reduce unused, last_use, fn shard, last_use ->
        Map.put(last_use, shard, :os.system_time(:millisecond))
      end
    end
  end

  defp shutdown_unused(state, unused) do
    Enum.each(unused, &shutdown_repo_for(state.repo, &1))
    state
  end

end

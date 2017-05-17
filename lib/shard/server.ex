defmodule Shard.Server do
  @moduledoc false
  
  use GenServer

  import Shard.Lib

  def start_link(options \\ [], gen_options \\ []) do
    GenServer.start_link(__MODULE__, options, gen_options)
  end

  def init(_options) do
    {
      :ok,
      %{
        repo_map: %{},
        proc_map: %{}
      }
    }
  end

  def handle_call({:set, nil}, {pid, _}, state) do
    state = state
      |> rem_proc(pid)
      |> rem_repo(pid)
    {:reply, :ok, state}
  end

  def handle_call({:set, shard}, {pid, _}, state) do
    Process.monitor(pid)

    ensure_repo_defined(shard)
    ensure_repo_started(shard)

    state = state
      |> rem_proc(pid)
      |> set_proc(shard, pid)
      |> set_repo(shard, pid)

    {:reply, :ok, state }
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
    state = state
      |> rem_proc(pid)
      |> rem_repo(pid)
    {:noreply, state}
  end

  defp ensure_repo_defined(shard) do
    repo = repo_for(shard)

    if !Code.ensure_loaded?(repo) do
      otp_app     = otp_app_for(shard)
      repo_config = repo_config_for(shard)

      # Dynamically define the otp_app configuration for the repo.
      # Why? Ecto repos just work that way. Lucky Elixir doesn't
      # complain about us writing configs for dummy/fake otp apps.
      Application.put_env(otp_app, repo, repo_config)

      # Dynamically define the repo module.
      definition = quote do: use Ecto.Repo, otp_app: unquote(otp_app)
      defmodule repo, do: Module.eval_quoted(__MODULE__, definition)
    end
  end

  defp ensure_repo_started(shard) do
    repo = repo_for(shard)
    if !Process.whereis(repo) do
      apply(repo, :start_link, [])
    end
  end

  defp set_repo(state, shard, pid) do
    put_in(state, [:repo_map, pid], shard)
  end

  defp set_proc(state, shard, pid) do
    proc_map = Map.put_new(state.proc_map, shard, MapSet.new)
    procs = MapSet.put(proc_map[shard], pid)
    put_in(state, [:proc_map, shard], procs)
  end

  defp rem_proc(state, pid) do
    shard = state.repo_map[pid]
    procs = state.proc_map[shard] || MapSet.new
    procs = MapSet.delete(procs, pid)

    if MapSet.size(procs) == 0 do
      shutdown_repo_for(shard)
      put_in(state.proc_map, Map.delete(state.proc_map, shard))
    else
      put_in(state, [:proc_map, shard], procs)
    end
  end

  defp rem_repo(state, pid) do
    repo_map = Map.delete(state.repo_map, pid)
    %{ state | repo_map: repo_map }
  end

end

defmodule Shard.Server do
  @moduledoc false

  use GenServer

  import Shard.Lib

  # TODO will this waste too many cycles?
  @cooldown_purge_interval 100

  @state Shard.Server.State.Ets

  def start_link(options, gen_options) do
    GenServer.start_link(__MODULE__, options, gen_options)
  end

  def init({repo, config}) do
    if config[:cooldown] do
      Process.send_after(self(), :cooldown_purge, @cooldown_purge_interval)
    end

    state = %{
      repo: repo,
      config: config,
    } |> @state.init

    {:ok, state}
  end

  def handle_call({:set, nil}, {pid, _}, state) do
    case @state.current(pid, state) do
      nil -> {:reply, :noop, state}
      _shard -> {:reply, :ok, unset(state, pid)}
    end
  end

  def handle_call({:set, shard}, {pid, _}, state) do
    case @state.current(pid, state) do
      ^shard -> {:reply, :noop, state} # Noop, they are already on this shard.
      nil -> {:reply, :ok, state |> set(pid, shard)}
      _ -> {:reply, :ok, state |> unset(pid) |> set(pid, shard)}
    end
  end

  # Private api called by Repo.delegate/3.
  def handle_call({:get, ancestor}, {_pid, _}, state) do
    {:reply, @state.current(ancestor, state), state}
  end

  def handle_call(:get, {pid, _}, state) do
    {:reply, @state.current(pid, state), state}
  end

  # There is no public api for this; it's just used for testing.
  # See test/support/test_helper.ex.
  # Returns the state of the gen server.
  def handle_call(:debug, _from, state) do
    {:reply, @state.debug(state), state}
  end

  # There is no public api for this; it's just used for testing.
  # See test/support/test_helper.ex.
  # Finds all repos and shuts them down.
  def handle_call(:reset, _from, state) do
    Enum.each @state.all_shards(state), fn shard ->
      shutdown_repo_for(state.repo, shard)
    end

    state = @state.reset(state)

    {:reply, :ok, state}
  end

  # Monitor processes that have called `set` for going down, then update our
  # internal state, potentially shutting down the repo if nothing else is
  # using it.
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, unset(state, pid)}
  end

  # Periodically wake up to purge unused repos.
  def handle_info(:cooldown_purge, state) do
    unused = @state.all_unused(state)

    state = Enum.reduce unused, state, fn {shard, timestamp}, state ->
      if now() - timestamp >= state.config[:cooldown] do
        shutdown_repo_for(state.repo, shard)
        @state.untrack_last_used(state, shard)
      else
        state
      end
    end

    Process.send_after(self(), :cooldown_purge, @cooldown_purge_interval)

    {:noreply, state}
  end

  defp unset(state, pid) do
    shard = @state.current(pid, state)
    state
      |> @state.set_current(pid, nil)
      |> @state.untrack_pid(pid, shard)
      |> @state.track_last_used(shard)
  end

  def set(state, pid, shard) do
    Process.monitor(pid)
    state
      |> ensure_repo_defined(shard)
      |> @state.track_shard(shard)
      |> @state.set_current(pid, shard)
      |> @state.track_pid(pid, shard)
      |> @state.untrack_last_used(shard)
  end

  defp ensure_repo_defined(%{repo: repo, config: config} = state, shard) do
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

    state
  end

end

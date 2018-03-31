defmodule Shard.Server.State do
  @moduledoc """
  This is the interface for interacting with `Shard.Server` state.

  I found myself constantly toying with and tweaking the implementation of
  `Shard.Server`. It was a very bug prone process.

  Obviously, abstracting out an interface addresses this problem exactly, duh.
  Play around with implementation all you want, just as long as it conforms to
  this interface.
  """

  @type repo :: Shard.Repo.t
  @type state :: %{required(:repo) => repo}
  @type shard :: String.t
  @type debug_info :: %{
    required(:shards) => [shard],
    required(:current) => %{pid => shard},
    required(:in_use) => %{shard => [pid]},
    required(:last_used) => %{shard => timestamp_in_ms}
  }
  @type timestamp_in_ms :: integer

  @doc """
  Initialize the state.
  """
  @callback init(state) :: state

  @doc """
  Keep track of all shards ever seen. (for debugging and book keeping).
  """
  @callback track_shard(state, shard) :: state

  @doc """
  Return a list of all shard ever seen.
  """
  @callback all_shards(state) :: [shard]

  @doc """
  Get the current shard for the given pid.
  """
  @callback current(pid, state) :: shard | nil

  @doc """
  Set the current shard for the given pid.
  """
  @callback set_current(state, pid, shard :: shard | nil) :: state

  @doc """
  Add pid to list of pids using a given shard.
  """
  @callback track_pid(state, pid, shard) :: state

  @doc """
  Remove pid from list of pids using a given shard.
  """
  @callback untrack_pid(state, pid, shard) :: state

  @doc """
  If a shard isn't in use, then mark its last used at.
  """
  @callback track_last_used(state, shard) :: state

  @doc """
  If a shard becomes used, remove it's last used mark.
  """
  @callback untrack_last_used(state, shard) :: state

  @doc """
  Get all unused shards and their last used timestamps.
  """
  @callback all_unused(state) :: [{shard, ms :: integer}]

  @doc """
  Debug the state.
  """
  @callback debug(state) :: debug_info

  @doc """
  Reset all state back to what init/1 returned.
  """
  @callback reset(state) :: state

end

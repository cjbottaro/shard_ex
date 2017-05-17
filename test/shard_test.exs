defmodule ShardTest do
  use ExUnit.Case

  alias Shard.TestHelper

  setup do
    TestHelper.reset
  end

  test "setting a shard" do
    Shard.set(:dev)
    state = TestHelper.debug

    assert MapSet.member?(state.proc_map[:dev], self())
    assert state.repo_map[self()] == :dev
  end

  test "changing a shard" do
    Shard.set(:dev)
    Shard.set(:alpha)
    state = TestHelper.debug

    assert Map.size(state.proc_map) == 1
    assert MapSet.size(state.proc_map[:alpha])
    assert MapSet.member?(state.proc_map[:alpha], self())

    assert Map.size(state.repo_map) == 1
    assert state.repo_map[self()] == :alpha
  end

  test "if no process is using a repo, it should be shutdown" do
    Shard.set(:dev)
    Shard.set(:alpha)

    repo = Shard.Lib.repo_for(:dev)
    assert Process.whereis(repo) == nil
    repo = Shard.Lib.repo_for(:alpha)
    assert Process.whereis(repo) != nil

    Shard.set(:dev)

    repo = Shard.Lib.repo_for(:dev)
    assert Process.whereis(repo) != nil
    repo = Shard.Lib.repo_for(:alpha)
    assert Process.whereis(repo) == nil
  end

  test "if a process dies, it should release the repo it was using" do
    task = Task.async(fn -> Shard.set(:dev) end)
    Task.await(task)

    # Gotta figure out how to wait long enough for the Shard.Server to finish
    # processing the :DOWN message from the above process exiting. Easiest way
    # I can think of is to put another message on and block until that message
    # is processed.
    TestHelper.debug

    repo = Shard.Lib.repo_for(:dev)
    assert Process.whereis(repo) == nil
  end

  test "if a process dies abnormally, it should release the repo too" do
    test_pid = self()
    {child_pid, _ref} = spawn_monitor fn ->
      Shard.set(:dev)
      send(test_pid, :ready)
      :timer.sleep(:infinity)
    end

    # Ensure Shard.set has been called.
    receive do
      :ready -> nil
    end

    # Kill it. Brutally.
    Process.exit(child_pid, :kill)

    # Ensure the brutal death has happened.
    receive do
      {:DOWN, _ref, :process, _pid, _reason} -> nil
    end

    # Make sure the Shard server has processed the brutal death also.
    TestHelper.debug

    repo = Shard.Lib.repo_for(:dev)
    assert Process.whereis(repo) == nil
  end

end

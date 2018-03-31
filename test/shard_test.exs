defmodule ShardTest do
  use ExUnit.Case

  alias Shard.TestRepo

  setup do
    TestRepo.reset
  end

  test "setting a shard" do
    TestRepo.set_shard(:dev)
    state = TestRepo.debug

    assert MapSet.member?(state.in_use["dev"], self())
    assert state.current[self()] == "dev"
  end

  test "changing a shard" do
    TestRepo.set_shard(:dev)
    TestRepo.set_shard(:alpha)
    state = TestRepo.debug

    assert Map.size(state.in_use) == 1
    assert MapSet.size(state.in_use["alpha"]) == 1
    assert MapSet.member?(state.in_use["alpha"], self())

    assert Map.size(state.current) == 1
    assert state.current[self()] == "alpha"
  end

  test "if no process is using a repo, it should be marked as unused" do
    TestRepo.set_shard(:dev)
    TestRepo.set_shard(:alpha)
    state = TestRepo.debug

    assert state.last_used["dev"]
    refute state.last_used["alpha"]

    TestRepo.set_shard(:dev)
    state = TestRepo.debug

    assert state.last_used["alpha"]
    refute state.last_used["dev"]
  end

  test "if a process dies, mark the repo as unused" do
    task = Task.async(fn -> TestRepo.set_shard(:dev) end)
    Task.await(task)

    # Gotta figure out how to wait long enough for the Shard.Server to finish
    # processing the :DOWN message from the above process exiting. Easiest way
    # I can think of is to put another message on and block until that message
    # is processed.
    state = TestRepo.debug

    assert state.last_used["dev"]
  end

  test "a shard should not be marked as used as long as something is using it" do
    {:ok, task} = Task.start_link fn ->
      TestRepo.set_shard(:dev)
      :timer.sleep(:infinity)
    end

    TestRepo.set_shard(:dev)

    state = TestRepo.debug
    assert MapSet.size(state.in_use["dev"]) == 2

    TestRepo.set_shard(nil)

    state = TestRepo.debug
    assert MapSet.size(state.in_use["dev"]) == 1
    refute state.last_used["dev"]

    # Cleanup
    Process.exit(task, :normal)
  end

  test "if a process dies abnormally, it should mark the repo as unused" do
    test_pid = self()
    {child_pid, _ref} = spawn_monitor fn ->
      TestRepo.set_shard(:dev)
      send(test_pid, :ready)
      :timer.sleep(:infinity)
    end

    # Ensure Shard.set_shard has been called.
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
    state = TestRepo.debug

    assert state.last_used["dev"]
  end

end

defmodule Shard.Server.StateTest do
  use ExUnit.Case

  @state Shard.Server.State.Ets

  setup_all do
    %{repo: __MODULE__} |> @state.init
  end

  setup(state) do
    @state.reset(state)
  end

  test "init and reset work" do
    assert true
  end

  test "setting / getting current", state do
    state = @state.set_current(state, 123, :alpha)

    assert @state.current(123, state) == :alpha
    assert @state.current(456, state) == nil
  end

  test "setting current to nil", state do
    state = @state.set_current(state, 123, :alpha)
    state = @state.set_current(state, 123, nil)

    assert @state.current(123, state) == nil
  end

end

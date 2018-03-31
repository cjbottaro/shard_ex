defmodule Shard.TestRepo do
  use Shard.Repo, otp_app: :shard

  def reset do
    GenServer.call(__MODULE__, :reset)
  end
end

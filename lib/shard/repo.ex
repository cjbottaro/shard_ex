defmodule Shard.Repo do

  defmacro __using__(options) do
    quote bind_quoted: [options: options] do

      @otp_app options[:otp_app]

      @doc false
      def start_link do
        Shard.Repo.start_link(__MODULE__, @otp_app)
      end

      @doc false
      def child_spec(options) do
        %{ id: __MODULE__, start: {__MODULE__, :start_link, options} }
      end

      @doc false
      def init(config), do: config
      defoverridable [init: 1]

      @doc false
      def shard_config(name), do: [database: name]
      defoverridable [shard_config: 1]

      @doc false
      def set_shard(db_name) do
        Shard.Repo.set_shard(__MODULE__, db_name)
      end

      @doc false
      def get_shard do
        Shard.Repo.get_shard(__MODULE__)
      end

      @doc false
      def use_shard(db_name, f) do
        Shard.Repo.use_shard(__MODULE__, db_name, f)
      end

      @doc false
      def debug do
        GenServer.call(__MODULE__, :debug)
      end

      # Define the Ecto delegates.
      # Note that Ecto.Repo does this the same way; it doesn't metaprogram it.

      @doc false
      def all(queryable, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :all, [queryable, opts])
      end

      @doc false
      def stream(queryable, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :stream, [queryable, opts])
      end

      @doc false
      def get(queryable, id, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :get, [queryable, id, opts])
      end

      @doc false
      def get!(queryable, id, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :get!, [queryable, id, opts])
      end

      @doc false
      def get_by(queryable, clauses, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :get_by, [queryable, clauses, opts])
      end

      @doc false
      def get_by!(queryable, clauses, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :get_by!, [queryable, clauses, opts])
      end

      @doc false
      def one(queryable, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :one, [queryable, opts])
      end

      @doc false
      def one!(queryable, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :one!, [queryable, opts])
      end

      @doc false
      def aggregate(queryable, aggregate, field, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :aggregate, [queryable, aggregate, field, opts])
      end

      @doc false
      def insert_all(schema_or_source, entries, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :insert_all, [schema_or_source, entries, opts])
      end

      @doc false
      def update_all(queryable, updates, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :update_all, [queryable, updates, opts])
      end

      @doc false
      def delete_all(queryable, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :delete_all, [queryable, opts])
      end

      @doc false
      def insert(struct, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :insert, [struct, opts])
      end

      @doc false
      def update(struct, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :update, [struct, opts])
      end

      @doc false
      def insert_or_update(changeset, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :insert_or_update, [changeset, opts])
      end

      @doc false
      def delete(struct, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :delete, [struct, opts])
      end

      @doc false
      def insert!(struct, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :insert!, [struct, opts])
      end

      @doc false
      def update!(struct, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :update!, [struct, opts])
      end

      @doc false
      def insert_or_update!(changeset, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :insert_or_update!, [changeset, opts])
      end

      @doc false
      def delete!(struct, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :delete!, [struct, opts])
      end

      @doc false
      def preload(struct_or_structs_or_nil, preloads, opts \\ []) do
        Shard.Repo.delegate(__MODULE__, :preload, [struct_or_structs_or_nil, preloads, opts])
      end

      @doc false
      def load(schema_or_types, data) do
        Shard.Repo.delegate(__MODULE__, :load, [schema_or_types, data])
      end

    end
  end

  def start_link(repo, otp_app) do
    config = Application.get_env(otp_app, repo)
      |> repo.init
      |> Enum.reject(fn {_, v} -> v == nil end) # Reject nil values.

    Shard.Server.start_link({repo, config}, name: repo)
  end

  def set_shard(module, shard) do
    shard = Shard.Lib.normalize_shard(shard)
    GenServer.call(module, {:set, shard})
  end

  def get_shard(module) do
    GenServer.call(module, :get)
  end

  def use_shard(module, shard, f) do
    previous = get_shard(module)
    set_shard(module, shard)
    try do
      f.()
    after
      set_shard(module, previous)
    end
  end

  def delegate(repo, fn_name, args) do
    case get_shard(repo) do
      nil -> raise ArgumentError, "no shard set, call #{inspect(repo)}.set first"
      shard ->
        repo = Shard.Lib.ecto_repo_for(repo, shard)
        apply(repo, fn_name, args)
    end
  end

end

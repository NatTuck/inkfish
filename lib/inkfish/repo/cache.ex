defmodule Inkfish.Repo.Cache do
  import Ecto.Query, warn: false
  alias Inkfish.Repo
  use OK.Pipe

  use GenServer

  ### FIXME:
  # The cached item should have no preloaded path,
  # and we should pull the appropriate items from cache
  # on request.
  #
  # This allows for parents to be invalidating without
  # invalidating all kids.

  ## Public Interface

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get(mod, id) do
    GenServer.call(__MODULE__, {:get, mod, id})
  end

  def drop(mod, id) do
    GenServer.call(__MODULE__, {:drop, mod, id})
  end

  def flush() do
    GenServer.call(__MODULE__, :flush)
  end

  def list(_mod, _filters) do
    # base =
    #  Repo.all(query)
  end

  ## GenServer Callbacks

  @impl true
  def init(_) do
    state = %{}
    {:ok, state}
  end

  @impl true
  def handle_call({:get, mod, id}, _from, state) do
    case _get_with_path(state, mod, id) do
      {:ok, state, item} ->
        {:reply, {:ok, item}, state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:drop, mod, id}, _from, state) do
    {_, state} = pop_in(state, [mod, id])
    {:reply, :ok, state}
  end

  def handle_call(:flush, _from, _state) do
    {:reply, :ok, %{}}
  end

  ## Public Support Functions

  def path(mod) do
    path(mod, [mod])
  end

  def path(mod, ys) do
    if {:ok, pmod} = parent_mod(mod) do
      path(pmod, [pmod | ys])
    else
      ys
    end
  end

  def parent_field(mod) do
    if function_exported?(mod, :parent, 0) do
      {:ok, mod.parent()}
    else
      {:error, :no_parent, mod}
    end
  end

  def parent_mod(mod) do
    with {:ok, pfield} <- parent_field(mod) do
      if pmod = mod.__schema__(:association, pfield).related do
        {:ok, pmod}
      else
        {:error, {:missing_assoc, mod, pfield}}
      end
    else
      _err -> {:error, {:no_parent, mod}}
    end
  end

  ## Internal Support Functions

  def _db_get(mod, id) do
    if item = Repo.get(mod, id) do
      {:ok, item}
    else
      {:error, "Not Found: #{mod} with id = #{id}"}
    end
  end

  def _get_with_path(state, mod, id) do
    if item = get_in(state, [mod, id]) do
      {:ok, state, item}
    else
      with {:ok, item} <- _db_get(mod, id),
           {:ok, state, item} <- _load_path(state, mod, item) do
        state =
          state
          |> Map.put_new(mod, %{})
          |> put_in([mod, id], item)

        {:ok, state, item}
      else
        error -> error
      end
    end
  end

  def _load_path(state, mod, item) do
    with {:ok, pfield} <- parent_field(mod),
         {:ok, pmod} <- parent_mod(mod),
         id_field <- mod.__schema__(:association, pfield).owner_key,
         {:ok, p_id} <- Map.fetch(item, id_field),
         {:ok, state, parent} <- _get_with_path(state, pmod, p_id) do
      IO.inspect({mod, :parent, pmod, parent})
      item = Map.put(item, pfield, parent)
      {:ok, state, item}
    else
      _err -> {:ok, state, item}
    end
  end
end

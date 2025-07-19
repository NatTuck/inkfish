defmodule Inkfish.Repo.Cache do
  import Ecto.Query, warn: false
  alias Inkfish.Repo
  use OK.Pipe

  # We're primarily caching objects and their paths.
  # Caching descendents is harder, since things get added.

  use GenServer

  import Inkfish.Repo.Info

  ## Public Interface

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get(mod, id) do
    GenServer.call(__MODULE__, {:get, mod, id})
  end

  @doc """
  List items associated with the provided mod.

  This always does a DB query for the list, then
  preloads the path, potentially from the cache.

  Clauses can be:
  - {field, value}: Gives items where the field matches.
  - {limit, N}: Limit
  - {offset, N}: Offset

  e.g. list(Assignment, limit: 10, offset: 20, course_id: 14)
  """
  def list(mod, clauses) do
    GenServer.call(__MODULE__, {:list, mod, clauses})
  end

  def drop(mod, id) when is_atom(mod) do
    GenServer.call(__MODULE__, {:drop, mod, id})
  end

  def drop(item) when is_struct(item) do
    drop(item.__struct__, item.id)
  end

  @doc """
  Repo.update(changeset)
  |> Repo.Cache.updated()
  """
  def updated({:ok, item}) do
    :ok = drop(item)
    {:ok, item}
  end

  def updated(other) do
    other
  end

  def flush() do
    GenServer.call(__MODULE__, :flush)
  end

  def flush(mod) when is_struct(mod) do
    GenServer.call(__MODULE__, {:flush, mod})
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

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:list, mod, clauses}, _from, state) do
    case _list_with_path(state, mod, clauses) do
      {:ok, state, xs} ->
        {:reply, {:ok, xs}, state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  ## FIXME:
  #
  # When we drop an item because it's invalid, that means any cached 
  # item with that item preloaded as a parent or default_preload becomes
  # invalid too.
  #
  # Two solutions:
  #  - Figure out what items those are and drop them too.
  #  - Don't include preloads in the cached objects; add the preloads,
  #    potentially from cache, at get time.
  #
  # Solution two is better, but will require rewriting the whole thing.

  def handle_call({:drop, mod, id}, _from, state) do
    {_item, state} = pop_in(state, [mod, id])
    # {:reply, :ok, state}
    {:reply, :ok, %{}}
  end

  def handle_call(:flush, _from, _state) do
    {:reply, :ok, %{}}
  end

  def handle_call({:flush, mod}, _from, state) do
    state = Map.put(state, mod, %{})
    # {:reply, :ok, state}
    {:reply, :ok, %{}}
  end

  ## Internal Support Functions

  def _db_get(mod, id) do
    if item = Repo.get(mod, id) do
      {:ok, item}
    else
      {:error, "Not Found: #{mod} with id = #{id}"}
    end
  end

  def _db_list(mod, clauses) do
    _db_list(mod, clauses, mod |> order_by(asc: :id))
  end

  def _db_list(_mod, [], query) do
    {:ok, Repo.all(query)}
  end

  def _db_list(mod, [{:limit, nn} | rest], query) do
    _db_list(mod, rest, query |> limit(^nn))
  end

  def _db_list(mod, [{:offset, nn} | rest], query) do
    _db_list(mod, rest, query |> offset(^nn))
  end

  def _db_list(mod, [{field, val} | rest], query) do
    if field in mod.__schema__(:fields) do
      filter = [{field, val}]
      _db_list(mod, rest, query |> where(^filter))
    else
      {:error, "No field #{field} in #{mod}"}
    end
  end

  def _list_with_path(state, mod, filters) do
    with {:ok, xs} <- _db_list(mod, filters) do
      {state, ys} =
        Enum.reduce(xs, {state, []}, fn item, {state, ys} ->
          {:ok, state, item} = _load_path(state, mod, item)
          {:ok, state, item} = _get_or_preload_and_store(state, mod, item)

          {state, [item | ys]}
        end)

      {:ok, state, Enum.reverse(ys)}
    end
  end

  def _get_with_path(state, mod, id) do
    if item = get_in(state, [mod, id]) do
      {:ok, state, item}
    else
      with {:ok, item} <- _db_get(mod, id),
           {:ok, state, item} <- _load_path(state, mod, item) do
        _get_or_preload_and_store(state, mod, item)
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
      # IO.inspect({mod, :parent, pmod, parent})
      item = Map.put(item, pfield, parent)
      {:ok, state, item}
    else
      _err -> {:ok, state, item}
    end
  end

  def _get_or_preload_and_store(state, mod, item) do
    item1 = get_in(state, [mod, item.id])

    if not is_nil(item1) && ts_eq(item.updated_at, item1.updated_at) do
      {:ok, state, item1}
    else
      item = _standard_preloads(mod, item)

      state =
        state
        |> Map.put_new(mod, %{})
        |> put_in([mod, item.id], item)

      {:ok, state, item}
    end
  end

  def _standard_preloads(mod, item) do
    if function_exported?(mod, :standard_preloads, 0) do
      preloads = mod.standard_preloads()
      Repo.preload(item, preloads)
    else
      item
    end
  end

  def ts_eq(ts1, ts2) do
    DateTime.compare(ts1, ts2) == :eq
  end
end

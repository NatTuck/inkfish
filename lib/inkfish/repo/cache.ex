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

  def flush(mod) do
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
    case _get_full(state, mod, id) do
      {:ok, state, item} ->
        {:reply, {:ok, item}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:list, mod, clauses}, _from, state) do
    case _list_full(state, mod, clauses) do
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
  #
  # Question: What about standard preloads?
  #  - We want to be able to cache them.
  #  - Scanning for them would be O(n), which is sub-optimal.
  #  - Cache them on load, re-get them on get.
  #
  # Remaining problem: has_many standard preloads

  def handle_call({:drop, mod, id}, _from, state) do
    {_item, state} = pop_in(state, [mod, id])
    {:reply, :ok, state}
  end

  def handle_call(:flush, _from, _state) do
    {:reply, :ok, %{}}
  end

  def handle_call({:flush, mod}, _from, state) do
    state = Map.put(state, mod, %{})
    {:reply, :ok, state}
  end

  ## Internal Support Functions
  def _put_item(state, mod, item) do
    state
    |> Map.put_new(mod, %{})
    |> put_in([mod, item.id], item)
  end

  def _get_item(state, mod, id) do
    case get_in(state, [mod, id]) do
      nil -> _db_get(state, mod, id)
      item -> {:ok, state, item}
    end
  end

  def _reget_items(state, mod, xs) do
    Enum.reduce(xs, {:ok, state, []}, fn item, {:ok, state, ys} ->
      {:ok, state, item} = _get_item(state, mod, item.id)
      {:ok, state, [item | ys]}
    end)
  end

  def _db_get(state, mod, id) when not is_nil(id) do
    if item = Repo.get(mod, id) do
      state = _put_item(state, mod, item)
      {:ok, state, item}
    else
      {:error, "Not Found: #{mod} with id = #{id}"}
    end
  end

  def _get_full(state, _mod, nil), do: {:ok, state, nil}

  def _get_full(state, mod, id) do
    with {:ok, state, item} <- _get_item(state, mod, id),
         {:ok, state, item} <- _add_assocs(state, mod, item) do
      {:ok, state, item}
    end
  end

  def _add_assocs(state, mod, item) do
    with {:ok, state, item} <- _add_preloads(state, mod, item),
         {:ok, state, item} <- _add_path(state, mod, item) do
      {:ok, state, item}
    end
  end

  def _add_preloads(state, mod, item) do
    fields = standard_preloads(mod)

    Enum.reduce(fields, {:ok, state, item}, fn field, stuff ->
      case stuff do
        {:ok, state, item} ->
          _add_one_preload(state, mod, item, field)

        error ->
          error
      end
    end)
  end

  alias Ecto.Association, as: Ea

  def _add_one_preload(state, mod, item, field) do
    assoc = mod.__schema__(:association, field)

    case assoc do
      %Ea.BelongsTo{related: amod, owner_key: akey} ->
        _add_belongs_to(state, item, field, amod, akey)

      %Ea.Has{related: amod, related_key: r_key} ->
        # Can't be _list_full, since that leads to
        # preload cycles.
        case _db_list(state, amod, [{r_key, item.id}]) do
          {:ok, state, ys} ->
            case assoc.cardinality do
              :one ->
                item = Map.put(item, field, hd(ys))
                {:ok, state, item}

              :many ->
                item = Map.put(item, field, ys)
                {:ok, state, item}
            end

          error ->
            error
        end

      %Ea.ManyToMany{} ->
        {:ok, state, Repo.preload(item, field)}
    end
  end

  def _add_belongs_to(state, item, field, amod, akey) do
    with {:ok, aid} <- Map.fetch(item, akey),
         {:ok, state, aitem} <- _get_full(state, amod, aid) do
      item = Map.put(item, field, aitem)
      {:ok, state, item}
    else
      _ ->
        item = Map.put(item, field, nil)
        {:ok, state, item}
    end
  end

  def _add_path(state, mod, item) do
    with {:ok, pfield} <- parent_field(mod),
         {:ok, pmod} <- parent_mod(mod),
         id_field <- mod.__schema__(:association, pfield).owner_key,
         {:ok, p_id} <- Map.fetch(item, id_field),
         {:ok, state, parent} <- _get_full(state, pmod, p_id) do
      {:ok, state, Map.put(item, pfield, parent)}
    else
      _error ->
        {:ok, state, item}
    end
  end

  def _db_list(state, mod, clauses) do
    _db_list(state, mod, clauses, mod |> order_by(asc: :id))
  end

  def _db_list(state, mod, [], query) do
    ys = Repo.all(query)

    state =
      Enum.reduce(ys, state, fn item, state ->
        _put_item(state, mod, item)
      end)

    {:ok, state, ys}
  end

  def _db_list(state, mod, [{:limit, nn} | rest], query) do
    _db_list(state, mod, rest, query |> limit(^nn))
  end

  def _db_list(state, mod, [{:offset, nn} | rest], query) do
    _db_list(state, mod, rest, query |> offset(^nn))
  end

  def _db_list(state, mod, [{field, val} | rest], query) do
    if field in mod.__schema__(:fields) do
      filter = [{field, val}]
      _db_list(state, mod, rest, query |> where(^filter))
    else
      {:error, "No field #{field} in #{mod}"}
    end
  end

  def _list_full(state, mod, filters) do
    with {:ok, state, xs} <- _db_list(state, mod, filters) do
      {state, ys} =
        Enum.reduce(xs, {state, []}, fn item, {state, ys} ->
          {:ok, state, item} = _add_assocs(state, mod, item)
          {state, [item | ys]}
        end)

      {:ok, state, Enum.reverse(ys)}
    end
  end

  def ts_eq(ts1, ts2) do
    DateTime.compare(ts1, ts2) == :eq
  end
end

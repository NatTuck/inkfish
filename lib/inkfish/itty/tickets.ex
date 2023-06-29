defmodule Inkfish.Itty.Tickets do
  use GenServer

  @doc """
  Itty Ticket Queue:

  - A collection of named ticket queues.
  - Each queue is {now_serving, next_ticket}

  """
  
  @name {:global, __MODULE__}

  def start do
    Singleton.start_child(__MODULE__, [], __MODULE__)
  end

  def ticket(qname) do
    :ok = Phoenix.PubSub.subscribe(Inkfish.PubSub, "autobots:#{qname}")
    GenServer.call(@name, {:ticket, qname})
  end

  def done(qname, ticket) do
    :ok = Phoenix.PubSub.unsubscribe(Inkfish.PubSub, "autobots:#{qname}")
    GenServer.call(@name, {:done, qname, ticket})
  end

  def peek(qname) do
    GenServer.call(@name, {:peek, qname})
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:ticket, qname}, _from, state0) do
    conc = concurrency(qname)
    {serving, ticket} = Map.get(state0, qname, {conc, 0})
    state1 = Map.put(state0, qname, {serving, ticket + 1})
    msg = {:now_serving, serving, ticket}
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "autobots:#{qname}", msg)
    {:reply, ticket, state1}
  end

  def handle_call({:done, qname, _done_ticket}, _from, state0) do
    {serving, ticket} = Map.get(state0, qname, {0, 1})
    serving = serving + 1
    state1 = Map.put(state0, qname, {serving, ticket})
    msg = {:now_serving, serving, ticket}
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "autobots:#{qname}", msg)
    {:reply, :ok, state1}
  end

  def handle_call({:peek, qname}, _from, state) do
    {:reply, Map.get(state, qname), state}
  end

  def concurrency(_qname) do
    conf = Application.get_env(:inkfish, Inkfish.Autobots)
    Keyword.get(conf, :concurrency, 1)
  end
end

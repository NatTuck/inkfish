defmodule Inkfish.Itty.Sup do
  use Supervisor

  alias Inkfish.Itty.Tickets

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Inkfish.Itty.DynSup},
      {Registry, keys: :unique, name: Inkfish.Itty.Reg},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def poll(qname) do
    alive = Enum.any? Supervisor.which_children(Inkfish.Itty.DynSup), fn {_, pid, _, _} ->
      {:ok, info} = GenServer.call(pid, :peek)
      qname == Map.get(info, :qname) && Map.get(info, :started)
    end

    unless alive do
      Tickets.done(qname, 1)
    end
  end
end

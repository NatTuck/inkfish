defmodule Inkfish.Ittys.Sup do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Inkfish.Ittys.DynSup},
      {Registry, keys: :unique, name: Inkfish.Ittys.Reg}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def poll(qname) do
    alive =
      Enum.any?(Supervisor.which_children(Inkfish.Ittys.DynSup), fn {_, pid, _,
                                                                     _} ->
        {:ok, info} = GenServer.call(pid, :peek)
        qname == Map.get(info, :qname) && Map.get(info, :started)
      end)

    if !alive do
      IO.puts("Poll found no survivors.")
    end
  end
end

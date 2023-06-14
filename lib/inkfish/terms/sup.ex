defmodule Inkfish.Terms.Sup do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Inkfish.Terms.DynSup},
      {Registry, keys: :unique, name: Inkfish.Terms.Reg},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

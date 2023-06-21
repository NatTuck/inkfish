defmodule Inkfish.Autobots.Sup do
  use Supervisor

  def start_link(a0) do
    Supervisor.state_link(__MODULE__, a0, name: __MODULE__)
  end

  @impl true
  def init(_) do
    workers = Application.get_env(:inkfish, Inkfish.Autobots)[:workers]
    children = Enum.map(1..workers, fn ii ->
      {Inkfish.Autobots.Worker, [ii]}
    end)
    Supervisor.init(children, strategy: :one_for_one)
  end
end


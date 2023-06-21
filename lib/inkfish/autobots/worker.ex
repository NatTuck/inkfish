defmodule Inkfish.Autobots.Worker do
  use GenServer

  alias Inkfish.Autobots.Queue

  def start_link(id) do
    GenServer.start_link(__MODULE__, %{id: id})
  end

  @impl true
  def init(state0) do
    :ok = Phoenix.PubSub.subscribe(Inkfish.PubSub, "autobots")
    Process.send_after(self(), :new_job, 10)
    {:ok, state0}
  end

  @impl true
  def handle_info(:new_job, state) do
    job = Queue.next()
    if job do
      work(state, job)
    end
    {:noreply, state}
  end

  def work(%{id: id}, job) do
    
  end
end

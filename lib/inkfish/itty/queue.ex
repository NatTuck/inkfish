defmodule Inkfish.Itty.Queue do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def schedule(queue, job) do
    GenServer.call(__MODULE__, {:schedule, queue, job})
  end

  def next(queue) do
    GenServer.call(__MODULE__, {:next, queue})
  end


  def init(state0) do
    {:ok, state0}
  end
  

  # TODO:
  #  - The rest of the queue logic.
  #  - The itty process shouldn't start until we're ready to run the external
  #    job, so we need to be able to query queue status before that.
  
end

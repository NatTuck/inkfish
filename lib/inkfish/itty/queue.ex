defmodule Inkfish.Itty.Queue do
  alias __MODULE__

  # FIXME: This is wrong too.
  defstruct [tasks: %{}, ready: [], running: [], done: []]

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def schedule(%Task{} = task) do
    GenServer.call(__MODULE__, {:schedule, task})
  end

  @impl true
  def init(state0) do
    {:ok, state0}
  end

  @impl true
  def handle_call({:schedule, %Task{} = task}, _from, state0) do
    queue = Map.get(state0, task.qname, [])
    |> insert_task(task)
    state1 = Map.put(state0, task.qname, queue)
    {:reply, {:ok, task.uuid}, state1}
  end

  # TODO:
  #  - The rest of the queue logic.
  #  - The itty process shouldn't start until we're ready to run the external
  #    job, so we need to be able to query queue status before that.

  def insert_task(queue, %Task{} = task) do
    queue = Enum.reject(queue, fn tt ->
      tt.uuid == task.uuid || (task.dupkey && tt.dupkey == task.dupkey)
    end)
    queue ++ [ task ]
  end
end

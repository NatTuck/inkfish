defmodule Inkfish.Itty.Queue do
  alias __MODULE__
  alias Inkfish.Itty.Task
  alias Inkfish.Itty

  defstruct ready: [], running: []

  @concurrency 2

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %Queue{}, name: __MODULE__)
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  def schedule(%Task{} = task) do
    Itty.stop(task.uuid)
    GenServer.call(__MODULE__, {:schedule, task})
  end

  def status(uuid) do
    GenServer.call(__MODULE__, {:status, uuid})
  end

  def poll() do
    GenServer.call(__MODULE__, :poll)
  end

  @impl true
  def init(state0) do
    {:ok, state0}
  end

  @impl true
  def handle_call(:list, _from, %Queue{} = queue) do
    delay_poll()
    {:reply, {:ok, queue}, queue}
  end
  
  def handle_call({:schedule, %Task{} = task}, _from, %Queue{} = queue) do
    Enum.each(queue.running, fn tt ->
      if task_conflict?(tt, task) do
        Itty.stop(tt.uuid)
      end
    end)

    queue = queue
    |> queue_poll()
    |> queue_schedule(task)

    {:reply, {:ok, task.uuid}, queue}
  end

  def handle_call({:status, uuid}, _from, %Queue{} = queue) do
    delay_poll()
    if Enum.any?(queue.running, &(&1.uuid == uuid)) do
      {:reply, :running}
    else
      case Enum.find_index(queue.ready, &(&1.uuid == uuid)) do
        nil -> {:reply, {:error, "No such task."}, queue}
        idx -> {:reply, {:ready, idx}, queue}
      end
    end
  end

  def handle_call(:poll, _from, %Queue{} = queue) do
    {:reply, :ok, queue}
  end

  @impl true
  def handle_info(:poll, %Queue{} = queue) do
    queue = queue_poll(queue)
    {:noreply, queue}
  end

  def delay_poll() do
    Process.send_after(self(), :poll, 100)
  end

  def spawn_next(%Queue{ready: []} = queue), do: queue

  def spawn_next(%Queue{ready: [task | ready], running: running} = queue) do
    Process.send_after(self(), :poll, 10_000)

    if length(running) < @concurrency do
      {:ok, _uuid} = Itty.start(task)
      %Queue{queue | running: [task | running], ready: ready}
    else
      queue
    end
  end

  def queue_poll(%Queue{running: running} = queue) do
    running = Enum.filter(running, &Itty.running?/1)
    spawn_next(%Queue{queue | running: running})
  end

  def queue_schedule(%Queue{} = queue, %Task{} = task) do
    task = %Task{task | state: :ready}

    ready =
      queue.ready
      |> Enum.reject(&task_conflict?(task, &1))
      |> Enum.concat([task])

    %Queue{queue | ready: ready}
  end

  def task_conflict?(%Task{} = t1, %Task{} = t2) do
    t1.uuid == t2.uuid || (dupkey(t1) && dupkey(t1) == dupkey(t2))
  end

  def dupkey(%Task{user_id: user_id, asg_id: asg_id}) do
    if is_nil(user_id) && is_nil(asg_id) do
      nil
    else
      {user_id, asg_id}
    end
  end
end

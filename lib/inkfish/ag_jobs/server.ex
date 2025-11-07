defmodule Inkfish.AgJobs.Server do
  use GenServer

  alias Inkfish.AgJobs
  alias Inkfish.AgJobs.AgJob
  alias Inkfish.AgJobs.Autograde
  alias Inkfish.Ittys

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def poll do
    GenServer.call(__MODULE__, :poll)
  end

  def cast_poll do
    GenServer.cast(__MODULE__, :poll)
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  def running?(ag_id) do
    GenServer.call(__MODULE__, {:running?, ag_id})
  end

  @impl true
  def init(_) do
    Inkfish.Sandbox.start_cleanups()

    state0 = %{}

    Process.send_after(self(), :do_poll, 5_000)
    {:ok, state0}
  end

  @impl true
  def handle_call(:poll, _from, state) do
    state = do_poll(state)
    {:reply, {:ok, state}, state}
  end

  def handle_call(:list, _from, state) do
    {:reply, state.running, state}
  end

  def handle_call({:running?, uuid}, _from, state) do
    yy = Enum.find(state.running, &(&1.uuid == uuid))
    {:reply, !is_nil(yy), state}
  end

  @impl true
  def handle_cast(:poll, state) do
    state = do_poll(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:do_poll, state) do
    Process.send_after(self(), :do_poll, 15 * 60_000)
    state = do_poll(state)
    {:noreply, state}
  end

  def do_poll(_state) do
    AgJobs.delete_old_ag_jobs()

    AgJobs.list_curr_ag_jobs()
    |> reap()
    |> schedule()
  end

  @doc """
  Check each running task:
  - Kill it if it has it its time limit.
  - Mark it if it's dead or done.
  """
  def reap(running) do
    Enum.filter(running, fn job ->
      if time_left(job) < 0 do
        IO.puts("Warning: timed out task didn't exit.")
        Ittys.stop(job.uuid)
      end

      running = Ittys.running?(job.uuid)

      if !running do
        AgJobs.update_ag_job(job, %{finished_at: LocalTime.now()})
        AgJobs.cleanup_resources(job)
      end

      running
    end)
  end

  def time_left(%AgJob{} = job) do
    time0 = job.started_at
    time1 = LocalTime.now()
    DateTime.diff(time1, time0)
  end

  def schedule(running) do
    machine_cores = get_config()[:resources][:cores]
    current_cores = count_cores(running)
    free_cores = machine_cores - current_cores

    case AgJobs.start_next_ag_job(free_cores) do
      {:ok, job} ->
        Autograde.autograde(job)

      {:error, _} ->
        :ok
    end

    %{}
  end

  def count_cores(jobs) do
    Enum.sum_by(jobs, &cores_needed/1)
  end

  def cores_needed(%AgJob{} = job) do
    for grade <- job.sub.grades do
      get_cores_limit(grade)
    end
    |> Enum.max()
  end

  def get_cores_limit(grade) do
    case Jason.decode(grade.grade_column.limits || "") do
      {:ok, %{"cores" => cores}} ->
        max(0.5, cores)

      # |> IO.inspect(label: "requested cores")

      _other ->
        # IO.inspect({:limits, other})
        1
    end
  end

  def get_config() do
    Application.get_env(:inkfish, Inkfish.AgJobs)
  end
end

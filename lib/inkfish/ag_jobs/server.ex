defmodule Inkfish.AgJobs.Server do
  use GenServer

  alias Inkfish.AgJobs
  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Itty
  alias Inkfish.Subs

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def poll do
    GenServer.call(__MODULE__, :poll)
  end

  def cast_poll do
    GenServer.cast(__MODULE__, :poll)
  end

  @impl true
  def init(_) do
    state0 = %{
      # grades, ag_job set, log_uuid set, gcol prloaded
      running: [],
      waiting: []
    }

    Process.send_after(self(), :do_poll, 10_000)

    {:ok, state0}
  end

  @impl true
  def handle_call(:poll, _from, state) do
    state = do_poll(state)
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_cast(:poll, state) do
    state = do_poll(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:do_poll, state) do
    Process.send_after(self(), :do_poll, 300_000)
    state = do_poll(state)
    {:noreply, state}
  end

  def do_poll(state) do
    AgJobs.delete_old_ag_jobs()

    state
    |> reap_tasks()
    |> mark_jobs()
    |> schedule()
  end

  @doc """
  Check each running task:
  - Kill it if it has it its time limit.
  - Remove it if it's dead or done.
  """
  def reap_tasks(state) do
    running =
      Enum.filter(state.running, fn grade ->
        uuid = grade.log_uuid

        if time_left(grade) < 0 do
          IO.puts("Warning: timed out task didn't exit.")
          Itty.stop(uuid)
        end

        Itty.running?(uuid)
      end)

    %{state | running: running}
  end

  def mark_jobs(state) do
    all_grade_ids =
      Enum.map(state.waiting ++ state.running, fn grade ->
        grade.id
      end)

    curr_jobs = AgJobs.list_curr_ag_jobs()

    Enum.each(curr_jobs, fn job ->
      ags = Subs.get_script_grades(job.sub)

      if !Enum.any?(ags, &Enum.member?(all_grade_ids, &1.id)) do
        AgJobs.update_ag_job(job, %{finished_at: LocalTime.now()})
      end
    end)

    state
  end

  def time_left(%Grade{} = grade) do
    time0 = grade.started_at
    time1 = LocalTime.now()
    DateTime.diff(time1, time0)
  end

  def schedule(state) do
    machine_cores = get_config()[:resources][:cores]
    current_cores = count_cores(state.running)
    cores_free = machine_cores - current_cores

    state
    |> load_queue(cores_free)
    |> start_tasks(cores_free)
  end

  def load_queue(state, cores_free) do
    if count_cores(state.waiting) < cores_free do
      case AgJobs.start_next_ag_job() do
        {:ok, job} ->
          grades =
            Inkfish.Subs.reset_script_grades(job.sub_id)
            |> Enum.map(&Grades.get_grade_for_autograding!(&1.id))
            |> Enum.map(&%Grade{&1 | ag_job: job})

          %{state | waiting: state.waiting ++ grades}
          |> load_queue(cores_free)

        {:error, _} ->
          state
      end
    else
      state
    end
  end

  def start_tasks(state, cores_left) do
    case state.waiting do
      [grade | rest] ->
        cores_req = get_cores_limit(grade)

        if cores_req <= cores_left do
          {:ok, _uuid} = Inkfish.AgJobs.Autograde.autograde(grade)

          grade = %Grade{grade | started_at: LocalTime.now()}

          running = [grade | state.running]
          state = %{state | running: running, waiting: rest}
          start_tasks(state, cores_left - cores_req)
        else
          state
        end

      [] ->
        state
    end
  end

  def count_cores(grades) do
    Enum.sum_by(grades, &get_cores_limit/1)
  end

  def get_cores_limit(grade) do
    case Jason.decode(grade.grade_column.limits) do
      {:ok, %{"cores" => cores}} ->
        max(0.5, cores)

      _else ->
        1
    end
  end

  def get_config() do
    Application.get_env(:inkfish, Inkfish.AgJobs)
  end
end

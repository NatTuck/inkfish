defmodule Inkfish.AgJobs.Server do
  use GenServer

  alias Inkfish.AgJobs.AgJob
  alias Inkfish.Itty

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def poll do
    GenServer.call(__MODULE__, :poll)
  end

  @impl true
  def init(_) do
    state0 = %{
      # AgJobs, grades preloaded, with log_uuid set, gcol prloaded
      running: [],
      waiting: []
    }

    {:ok, state0}
  end

  @impl true
  def handle_call(:poll, _from, state) do
    state =
      state
      |> reap_jobs()

    {:reply, :ok, state}
  end

  @doc """
  Check each running job:
  - Kill it if it has it its time limit.
  - Remove it if it's dead or done.
  """
  def reap_jobs(state) do
    running =
      Enum.filter(state.running, fn job ->
        uuid = job.grade.log_uuid

        # Itty should support time limits?
        if job_time_left(job) < 0 do
          Itty.stop(uuid)
        end

        Itty.running?(uuid)
      end)

    %{state | running: running}
  end

  def job_time_left(%AgJob{} = job) do

  end

  def job_limit_seconds(%AgJob
end

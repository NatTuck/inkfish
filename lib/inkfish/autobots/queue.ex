defmodule Inkfish.Autobots.Queue do
  use GenServer

  @name {:global, __MODULE__}

  alias Inkfish.Itty

  def start do
    Singleton.start_child(__MODULE__, [], __MODULE__)
  end

  def list() do
    GenServer.call(@name, :list)
  end

  def add(grade) do
    GenServer.call(@name, {:add, grade})
  end

  def next() do
    GenServer.call(@name, :next)
  end

  def cancel(grade_id) do
    GenSever.call(@name, {:cancel, grade_id})
  end

  @impl true
  def init(_) do
    state = %{
      jobs: [],
    }
    {:ok, state}
  end

  def handle_call(:list, _from, state) do
    {:reply, state.jobs, state}
  end

  def handle_call({:add, grade}, _from, state) do
    jobs = Enum.filter(state.jobs, &(&1.id != grade.id))
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "autobots", :new_job)
    {:reply, :ok, %{state | jobs: (jobs ++ [grade])}}
  end

  def handle_call(:next, _from, state) do
    case state.jobs do
      [job | jobs] ->
	{:reply, job, %{state | jobs: jobs}}
      [] ->
	{:reply, nil, state}
    end
  end

  def handle_call({:cancel, job_id}, _from, state) do
    jobs = Enum.filter(state.jobs, &(&1.id != job_id))
    {:reply, :ok, %{state | jobs: jobs}}
  end
end

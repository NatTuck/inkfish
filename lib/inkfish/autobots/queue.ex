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

  def next(grade) do
    GenServer.call(@name, :next)
  end

  def cancel(grade_id) do
    GenSever.call(@name, {:cancel, grade_id})
  end

  @impl true
  def init(_) do
    state = %{
      jobs: EQ.new(),
    }
    {:ok, state}
  end

  def handle_call(:list, _from, state) do
    {:reply, EQ.to_list(state.jobs), state}
  end

  def handle_call({:add, grade}, _from, state) do
    jobs = EQ.push(state.jobs, grade)
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "autobots", :new_job)
    {:reply, :ok, %{state | jobs: jobs}}
  end

  def handle_call(:next, _from, state) do
    case EQ.pop(state, state.jobs) do
      {{:value, job}, jobs} ->
	{:reply, job, %{state | jobs: jobs}}
      {:empty, _} ->
	{:reply, nil, state}
    end
  end

  def handle_call({:cancel, job_id}, _from, state) do
    jobs = EQ.filter(state.jobs, &(&1.id != job_id))
    {:reply, :ok, %{state | jobs: jobs}}
  end
end

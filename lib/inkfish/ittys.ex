defmodule Inkfish.Ittys do
  alias Inkfish.Ittys.Server
  alias Inkfish.Ittys.Task
  alias Inkfish.Ittys.Job

  def start(%Job{} = job) do
    Server.start(job)
    {:ok, job.uuid}
  end

  def start(%Task{} = task) do
    start(Job.new([task]))
  end

  def run(script) do
    Task.new(script)
    |> start()
  end

  def run(script, env) do
    Task.new(script, env)
    |> start()
  end

  def peek(uuid) do
    Server.peek(uuid)
  end

  def running?(%Task{} = task), do: running?(task.uuid)

  def running?(uuid) do
    Server.running?(uuid)
  end

  def open(uuid) do
    :ok = Phoenix.PubSub.subscribe(Inkfish.PubSub, "ittys:" <> uuid)
    peek(uuid)
  end

  def close(uuid) do
    Phoenix.PubSub.unsubscribe(Inkfish.PubSub, "ittys:" <> uuid)
    peek(uuid)
  end

  def stop(uuid) do
    Server.stop(uuid)
  end

  def list() do
    Registry.select(Inkfish.Itty.Reg, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end

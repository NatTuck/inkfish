defmodule Inkfish.Itty do
  alias Inkfish.Itty.Server
  alias Inkfish.Itty.Task
  alias Inkfish.Itty.Queue

  def start(%Task{} = task) do
    {:ok, _pid} = Server.start(task)
    {:ok, task.uuid}
  end

  def run(script) do
    Task.new(script)
    |> start()
  end

  def run(script, env) do
    env =
      env
      |> Enum.map(fn {kk, vv} ->
        {to_string(kk), to_string(vv)}
      end)
      |> Enum.into(%{})

    Task.new_env(script, env)
    |> start()
  end

  def schedule(%Task{} = task) do
    Queue.schedule(task)
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

  def status(uuid) do
    Queue.status(uuid)
  end

  def poll() do
    Queue.poll()
  end
end

defmodule Inkfish.Itty do
  alias Inkfish.Itty.Server
  alias Inkfish.Itty.Task

  def start(%Task{} = task) do
    Server.start(task)
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

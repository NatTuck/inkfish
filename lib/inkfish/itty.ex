defmodule Inkfish.Itty do
  alias Inkfish.Itty.Server
  alias Inkfish.Itty.Task
  alias Inkfish.Itty.Queue

  def start(%Task{} = task) do
    {:ok, _pid} = Server.start(task)
    :ok
  end

  def run(script) do
    Task.new(script)
    |> Queue.schedule()
  end

  def run2(script, dupkey) do
    Task.new(script)
    |> Queue.schedule()
  end

  def run3(qname, script, env) do
    env = env
    |> Enum.map(fn {kk, vv} ->
      {to_string(kk), to_string(vv)}
    end)
    |> Enum.into(%{})

    task = Task.new(script)
    %Task{ task | qname: qname, env: env }
    |> Queue.schedule()
  end
  
  def peek(uuid) do
    Server.peek(uuid)
  end

  def open(uuid) do
    :ok = Phoenix.PubSub.subscribe(Inkfish.PubSub, "ittys:" <> uuid)
    peek(uuid)
  end

  def close(uuid) do
    Phoenix.PubSub.unsubscribe(Inkfish.PubSub, "ittys:" <> uuid)
    peek(uuid)
  end
end

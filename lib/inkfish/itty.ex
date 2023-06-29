defmodule Inkfish.Itty do
  alias Inkfish.Itty.Server

  def run(uuid, qname, script, env, on_exit) do
    {:ok, _pid} = Server.start(uuid, qname, script, env, on_exit)
    {:ok, uuid}
  end
  
  def run(uuid, script) do
    {:ok, _pid} = Server.start(uuid, :default, script, %{}, &(&1))
    {:ok, uuid}
  end

  def run(script) do
    uuid = Inkfish.Text.gen_uuid()
    run(uuid, script)
  end

  def run3(qname, script, env) do
    env = env
    |> Enum.map(fn {kk, vv} ->
      {to_string(kk), to_string(vv)}
    end)
    |> Enum.into(%{})

    uuid = Inkfish.Text.gen_uuid()
    run(uuid, qname, script, env, &(&1))
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

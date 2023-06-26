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
  
  def open(uuid) do
    :ok = Phoenix.PubSub.subscribe(Inkfish.PubSub, "ittys:" <> uuid)
    Server.peek(uuid)
  end

  def close(uuid) do
    Phoenix.PubSub.unsubscribe(Inkfish.PubSub, "ittys:" <> uuid)
  end
end

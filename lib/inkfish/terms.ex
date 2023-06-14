defmodule Inkfish.Terms do
  alias Inkfish.Terms.Server

  def open(uuid) do
    :ok = Phoenix.PubSub.subscribe(Inkfish.PubSub, "terms:" <> uuid)
    Server.peek(uuid)
  end

  def close(uuid) do
    Phoenix.PubSub.unsubscribe(Inkfish.PubSub, "terms:" <> uuid)
  end

  def run(script) do
    uuid = Inkfish.Text.gen_uuid()
    {:ok, _pid} = Server.start(uuid, script)
    {:ok, uuid}
  end
end

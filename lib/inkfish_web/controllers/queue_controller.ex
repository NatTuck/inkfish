defmodule InkfishWeb.QueueController do
  use InkfishWeb, :controller1
  
  def list(conn, _params) do
    {:ok, queue} = Inkfish.Itty.Queue.list()
    render(conn, :list, queue: queue)
  end
end

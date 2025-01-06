defmodule InkfishWeb.QueueController do
  use InkfishWeb, :controller1
  
  def list(conn, _params) do
    {:ok, queue} = Inkfish.Itty.Queue.list()
    running = Enum.map queue.running, fn task ->
      task
    end
    ready = Enum.map queue.ready, fn task ->
      task
    end
    render(conn, :list, running: running, ready: ready)
  end
end

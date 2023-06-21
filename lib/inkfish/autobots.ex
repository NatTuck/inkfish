defmodule Inkfish.Autobots do
  alias Inkfish.Autobots.Queue

  def enqueue(job) do
    Queue.add(job)
  end

  def list_queue() do
    Queue.list()
  end
end

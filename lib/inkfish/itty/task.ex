defmodule Inkfish.Itty.Task do
  alias __MODULE__

  defstruct [uuid: nil, qname: :default, script: "echo hello, world",
             dupkey: nil, env: %{}, on_exit: &Task.default_on_exit/1]

  def new(script) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script}
  end

  def new(script, dupkey) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script, dupkey: dupkey}
  end

  def default_on_exit(rv) do
    IO.inspect({:itty_done, rv})
  end
end

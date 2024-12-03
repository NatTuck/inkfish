defmodule Inkfish.Itty.Task do
  alias __MODULE__

  defstruct [uuid: nil, script: "echo hello, world", dupkey: nil, state: nil,
             env: %{}, on_exit: &Task.default_on_exit/1]
  
  def new(script) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script}
  end

  def new(script, dupkey) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script, dupkey: dupkey}
  end

  def new_env(script, env) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script, env: env}
  end

  def default_on_exit(rv) do
    IO.inspect({:itty_done, rv})
  end
end

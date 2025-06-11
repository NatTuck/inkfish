defmodule Inkfish.Itty.Task do
  alias __MODULE__

  defstruct uuid: nil,
            cmd: "echo hello, world",
            grade: nil,
            state: nil,
            env: %{},
            cookie: nil,
            on_exit: &Task.default_on_exit/1,
            done: false

  def new(cmd) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, cmd: cmd}
  end

  def new(cmd, grade) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, cmd: cmd, grade: grade}
  end

  def new_env(cmd, env) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, cmd: cmd, env: env}
  end

  def default_on_exit(rv) do
    IO.inspect({:itty_done, rv})
  end
end

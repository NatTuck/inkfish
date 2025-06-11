defmodule Inkfish.Itty.Task do
  alias __MODULE__

  defstruct uuid: nil,
            script: "echo hello, world",
            grade: nil,
            state: nil,
            env: %{},
            queued_at: nil,
            started_at: nil,
            on_exit: &Task.default_on_exit/1

  def new(script) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script}
  end

  def new(script, grade) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script, grade: grade}
  end

  def new_env(script, env) do
    uuid = Inkfish.Text.gen_uuid()
    %Task{uuid: uuid, script: script, env: env}
  end

  def default_on_exit(rv) do
    IO.inspect({:itty_done, rv})
  end

  alias Inkfish.Grades

  def view_task(%Task{} = task) do
    grade = Grades.preload_for_task_view(task.grade)

    %{
      state: task.state,
      queued_at: task.queued_at,
      started_at: task.started_at,
      grade: grade
    }
  end
end

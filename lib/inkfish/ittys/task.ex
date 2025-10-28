defmodule Inkfish.Ittys.Task do
  alias __MODULE__

  defstruct label: "Generic Task",
            action: {:cmd, "echo hello, world"},
            cookie: nil,
            on_exit: nil,
            env: %{}

  def new(cmd, env) do
    action = {:cmd, cmd}
    cookie = Inkfish.Text.gen_uuid()
    env = norm_env(env)
    %Task{action: action, cookie: cookie, env: env}
  end

  def new(cmd) do
    new(cmd, [])
  end

  def norm_env(vars) do
    vars
    |> Enum.map(fn {kk, vv} ->
      {to_string(kk), to_string(vv)}
    end)
    |> Enum.into(%{})
  end

  def put_env(%Task{} = task, key, val) do
    %Task{task | env: Map.put(task.env, key, val)}
  end
end

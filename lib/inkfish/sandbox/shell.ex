defmodule Inkfish.Sandbox.Shell do
  @doc """
  Run text as a shell script.

  This is *not* sandboxed.
  """
  def run_script(text) do
    {:ok, script} = Briefly.create()
    File.write!(script, text)
    {text, code} = System.cmd("bash", [script], stderr_to_stdout: true)
    File.rm(script)

    if code == 0 do
      :ok
    else
      {:error, text}
    end
  end

  def run_script!(text) do
    :ok = run_script(text)
  end
end

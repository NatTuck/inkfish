defmodule RunAgJob do
  alias Inkfish.Sandbox.Containers

  def start(job_id) do
    {id, _conf} = Containers.create(image: "sandbox:#{job_id}")
    IO.puts("Container: #{id}")
  end
end

[arg1] = System.argv()
{job_id, _} = Integer.parse(arg1)
RunAgJob.start(job_id)

defmodule Inkfish.Ittys.Job do
  defstruct uuid: nil,
            tasks: [],
            seq: 100,
            blocks: [],
            ag_job: nil,
            ospid: nil,
            cookie: nil

  alias __MODULE__

  def new(tasks, ag_job \\ nil) do
    uuid =
      if ag_job do
        ag_job.uuid
      else
        Inkfish.Text.gen_uuid()
      end

    cookie = Inkfish.Text.gen_uuid()

    %Job{uuid: uuid, tasks: tasks, ag_job: ag_job, cookie: cookie}
  end
end

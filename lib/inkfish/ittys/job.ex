defmodule Inkfish.Ittys.Job do
  defstruct uuid: nil,
            tasks: [],
            seq: 100,
            blocks: [],
            ag_job: nil,
            ospid: nil

  alias __MODULE__

  def new(tasks, ag_job \\ nil) do
    uuid = Inkfish.Text.gen_uuid()
    %Job{uuid: uuid, tasks: tasks, ag_job: ag_job}
  end
end

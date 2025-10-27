defmodule Inkfish.Ittys.Job do
  defstruct uuid: nil,
            tasks: [],
            seq: 100,
            blocks: [],
            ospid: nil

  alias __MODULE__

  def new(tasks) do
    uuid = Inkfish.Text.gen_uuid()
    %Job{uuid: uuid, tasks: tasks}
  end
end

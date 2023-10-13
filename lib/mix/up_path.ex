defmodule Mix.Tasks.Up.Path do
  use Mix.Task

  def run(_) do
    Inkfish.Uploads.Upload.upload_base()
    |> IO.puts()
  end
end

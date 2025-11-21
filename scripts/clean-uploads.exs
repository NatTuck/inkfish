defmodule CleanUploads do
  alias Inkfish.Uploads.Upload
  alias Inkfish.Repo
  import Ecto.Query, warn: false

  def delete_upload(%Upload{} = upload) do
    dpath = Upload.upload_dir(upload)

    if String.length(dpath) > 10 do
      File.rm_rf!(dpath)
      File.rmdir(Path.dirname(dpath))
    end

    Repo.delete(upload)
    |> Repo.Cache.updated()
  end

  def run() do
    date = LocalTime.from!("2025-11-18 00:00:01")
    xs = Repo.all from up in Upload,
      where: up.user_id == ^86 and up.inserted_at >= ^date,
      preload: :subs
    IO.inspect({:cleaning, length(xs)})
    Enum.each(xs, fn up ->
      if up.user_id == 86 && length(up.subs) == 0 do
        delete_upload(up)
      else
        IO.inspect(up)
      end
    end)
  end 
end

CleanUploads.run()

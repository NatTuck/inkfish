defmodule Inkfish.Autobots.Autograde do
  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Uploads
  alias Inkfish.Uploads.Upload
  alias Inkfish.Itty

  def autograde(grade) do
    {:ok, temp} = Briefly.create(directory: true)

    unpacked_sub = Upload.unpacked_path(grade.sub.upload)
    unpacked_gra = Upload.unpacked_path(grade.grade_column.upload)

    script_dir = Application.app_dir(:inkfish)
    |> Path.join("priv/scripts")

    grade_script = script_dir
    |> Path.join("simple-grade.pl")

    env = %{
      "SCR" => script_dir,
      "SUB" => unpacked_sub,
      "GRA" => unpacked_gra,
    }
    
    Itty.run grade.log_uuid, :autobots, grade_script, env, fn result ->
      IO.inspect {:itty_done, result}
    end
  end
end

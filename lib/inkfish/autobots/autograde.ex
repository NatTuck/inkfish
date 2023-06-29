defmodule Inkfish.Autobots.Autograde do
  alias Inkfish.Grades
  alias Inkfish.Uploads.Upload
  alias Inkfish.Itty

  def autograde(grade) do
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
    
    Itty.run grade.log_uuid, :autobots, grade_script, env, fn rv ->
      {:ok, {passed, tests}} = Inkfish.Autobots.Tap.score(rv.result)

      Grades.set_grade_log!(rv.uuid, rv)
      Grades.set_grade_score(grade, passed, tests)
    end
  end
end

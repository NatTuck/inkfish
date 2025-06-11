defmodule Inkfish.AgJobs.Autograde do
  alias Inkfish.Grades
  alias Inkfish.Uploads.Upload
  alias Inkfish.Itty
  alias Inkfish.Itty.Task
  alias Inkfish.AgJobs.Tap

  def autograde(grade) do
    unpacked_sub = Upload.unpacked_path(grade.sub.upload)
    unpacked_gra = Upload.unpacked_path(grade.grade_column.upload)

    script_dir =
      Application.app_dir(:inkfish)
      |> Path.join("priv/scripts")

    grade_script =
      script_dir
      |> Path.join("simple-grade.pl")

    env = %{
      "SCR" => script_dir,
      "SUB" => unpacked_sub,
      "GRA" => unpacked_gra
    }

    on_exit = fn rv ->
      {:ok, {passed, tests}} = Tap.score(rv.result)

      Grades.set_grade_log!(rv.uuid, rv)
      Grades.set_grade_score(grade, passed, tests)

      Inkfish.AgJobs.Server.cast_poll()
    end

    %Task{
      uuid: grade.log_uuid,
      script: grade_script,
      env: env,
      on_exit: on_exit,
      grade: grade
    }
    |> Itty.start()
  end
end

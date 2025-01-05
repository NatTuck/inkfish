defmodule Inkfish.Autobots.Autograde do
  alias Inkfish.Grades
  alias Inkfish.Uploads.Upload
  alias Inkfish.Itty
  alias Inkfish.Itty.Task

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
      {:ok, {passed, tests}} = Inkfish.Autobots.Tap.score(rv.result)

      Grades.set_grade_log!(rv.uuid, rv)
      Grades.set_grade_score(grade, passed, tests)
    end

    %Task{uuid: grade.log_uuid, script: grade_script, env: env, on_exit: on_exit,
          user_id: grade.sub.reg.user_id, asg_id: grade.sub.assignment_id}
    |> Itty.schedule()
  end
end

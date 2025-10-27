defmodule Inkfish.AgJobs.Autograde do
  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Uploads.Upload
  alias Inkfish.Ittys
  alias Inkfish.Ittys.Task
  alias Inkfish.AgJobs.Tap

  def autograde(%Grade{} = grade) do
    # IO.inspect({:autograde, grade})

    unpacked_sub = Upload.unpacked_path(grade.sub.upload)
    unpacked_gra = Upload.unpacked_path(grade.grade_column.upload)

    script_dir =
      Application.app_dir(:inkfish)
      |> Path.join("priv/scripts")

    grade_script =
      script_dir
      |> Path.join("autograde-v4.pl")

    cookie = Inkfish.Text.gen_uuid()

    on_exit = fn rv ->
      {:ok, {passed, tests}} = Tap.score(rv.result)

      Grades.set_grade_log!(rv.uuid, rv)
      Grades.set_grade_score(grade, passed, tests)

      Inkfish.AgJobs.Server.cast_poll()
    end

    conf = %{
      "GID" => grade.id,
      "SCR" => script_dir,
      "SUB" => unpacked_sub,
      "GRA" => unpacked_gra,
      "BASE" => "inkfish:latest",
      "CMD" => ["perl", "/var/tmp/driver.pl"]
    }

    %Task{
      action: {:autograde, grade_script},
      env: conf,
      cookie: cookie,
      on_exit: on_exit
    }
    |> Ittys.start()
  end
end

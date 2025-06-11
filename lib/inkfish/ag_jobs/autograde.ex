defmodule Inkfish.AgJobs.Autograde do
  alias Inkfish.Grades
  alias Inkfish.Uploads.Upload
  alias Inkfish.Itty
  alias Inkfish.Itty.Task
  alias Inkfish.AgJobs.Tap
  alias Inkfish.Sandbox.Containers

  def autograde(grade) do
    IO.inspect({:autograde, grade})

    unpacked_sub = Upload.unpacked_path(grade.sub.upload)
    unpacked_gra = Upload.unpacked_path(grade.grade_column.upload)

    script_dir =
      Application.app_dir(:inkfish)
      |> Path.join("priv/scripts")

    grade_script =
      script_dir
      |> Path.join("autograde-v3.pl")

    on_exit = fn rv ->
      {:ok, {passed, tests}} = Tap.score(rv.result)

      Grades.set_grade_log!(rv.uuid, rv)
      Grades.set_grade_score(grade, passed, tests)

      Inkfish.AgJobs.Server.cast_poll()
    end

    cookie = Inkfish.Text.gen_uuid()

    cont_id =
      Containers.create(%{
        cmd: ["perl", "/var/tmp/driver.pl"],
        env: ["COOKIE=#{cookie}"],
        image: "inkfish:latest"
      })

    IO.puts("created container: #{cont_id} for grade #{grade.id}")

    env = %{
      "SCR" => script_dir,
      "SUB" => unpacked_sub,
      "GRA" => unpacked_gra
    }

    %Task{
      uuid: grade.log_uuid,
      cmd: "#{grade_script} #{cont_id}",
      env: env,
      cookie: cookie,
      on_exit: on_exit,
      grade: grade
    }
    |> Itty.start()
  end
end

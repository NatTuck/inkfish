defmodule Inkfish.AgJobs.Autograde do
  alias Inkfish.AgJobs
  alias Inkfish.AgJobs.AgJob
  alias Inkfish.Subs.Sub
  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Uploads.Upload
  alias Inkfish.Ittys
  alias Inkfish.Ittys.Job
  alias Inkfish.Ittys.Task
  alias Inkfish.AgJobs.Tap

  def autograde(%AgJob{} = ag_job) do
    ag_job = AgJobs.preload_for_autograde(ag_job)

    # IO.inspect({:autograde, grade})
    Enum.flat_map(ag_job.sub.grades, fn grade ->
      if grade.grade_column.kind == "script" do
        create_grade_tasks(ag_job, grade)
      else
        []
      end
    end)
    |> Job.new(ag_job)
    |> Ittys.start()
  end

  def create_grade_tasks(%AgJob{} = ag_job, %Grade{} = grade) do
    [
      build_image_task(ag_job, grade),
      start_container_task(ag_job, grade)
    ]
  end

  def build_image_task(%AgJob{} = ag_job, %Grade{} = grade) do
    unpacked_sub = Upload.unpacked_path(ag_job.sub.upload)
    unpacked_gra = Upload.unpacked_path(grade.grade_column.upload)

    script_dir =
      Application.app_dir(:inkfish)
      |> Path.join("priv/scripts")

    grade_script =
      script_dir
      |> Path.join("autograde-v4.pl")

    conf = %{
      script_dir: script_dir,
      unpacked_sub: unpacked_sub,
      unpacked_gra: unpacked_gra,
      grade_script: grade_script,
      ag_job_id: ag_job.id,
      cmd: ["perl", "/var/tmp/driver.pl"]
    }

    %Task{
      label: "Build container image",
      action: {:build_image, conf}
    }
  end

  def start_container_task(%AgJob{} = ag_job, %Grade{} = grade) do
    on_exit = fn rv ->
      {:ok, {passed, tests}} = Tap.score(rv.result)

      Grades.set_grade_log!(rv.uuid, rv)
      Grades.set_grade_score(grade, passed, tests)

      Inkfish.AgJobs.Server.cast_poll()
    end

    cookie = Inkfish.Text.gen_uuid()

    %Task{
      label: "Run container",
      action: {:run_container, ag_job},
      cookie: cookie,
      on_exit: on_exit
    }
  end
end

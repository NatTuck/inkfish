defmodule Inkfish.AgJobs.AutogradeTest do
  use Inkfish.DataCase, async: true

  import Mimic
  alias Inkfish.AgJobs.Autograde
  alias Inkfish.Ittys
  alias Inkfish.Ittys.Job
  alias Inkfish.Repo

  import Inkfish.Factory

  describe "autograde/1" do
    test "constructs a task and passes it to Itty.start/1" do
      Mimic.copy(Inkfish.Ittys)
      Mimic.copy(Inkfish.Sandbox.Containers)

      # Setup: Create the necessary database records.
      # A grade needs a submission and a grade_column, which in turn
      # need uploads.
      assignment = insert(:assignment)
      sub_upload = insert(:upload)
      sub = insert(:sub, assignment: assignment, upload: sub_upload)
      gc_upload = insert(:upload)

      grade_column =
        insert(:grade_column,
          kind: "script",
          assignment: assignment,
          upload: gc_upload
        )

      # grade =
      insert(:grade, sub: sub, grade_column: grade_column)
      |> Repo.preload(sub: :upload, grade_column: :upload)

      ag_job = insert(:ag_job, sub: sub, sub_id: sub.id)

      expect(Ittys, :start, fn %Job{} = job ->
        # Assert that the task passed to Itty contains the grade we created.
        assert job.ag_job.sub.id == sub.id
        {:ok, job}
      end)

      # expect(Containers, :create, fn conf ->
      #  assert is_list(conf.cmd)
      # end)

      Autograde.autograde(ag_job)

      verify!()
    end

    test "passes seconds timeout via environment variable" do
      Mimic.copy(Inkfish.Ittys)
      Mimic.copy(Inkfish.Sandbox.Containers)

      assignment = insert(:assignment)
      sub_upload = insert(:upload)
      sub = insert(:sub, assignment: assignment, upload: sub_upload)
      gc_upload = insert(:upload)

      grade_column =
        insert(:grade_column,
          kind: "script",
          assignment: assignment,
          upload: gc_upload,
          limits:
            "{\"cores\":1,\"megs\":1024,\"seconds\":600,\"allow_fuse\":false}"
        )

      insert(:grade, sub: sub, grade_column: grade_column)

      ag_job =
        insert(:ag_job, sub: sub, sub_id: sub.id)
        |> Repo.preload(sub: [:upload, grades: [grade_column: [:upload]]])

      expect(Ittys, :start, fn %Job{} = job ->
        run_task = Enum.find(job.tasks, fn t -> t.label == "Run container" end)
        assert run_task != nil
        assert run_task.env["SECONDS"] == "600"
        {:ok, job}
      end)

      Autograde.autograde(ag_job)

      verify!()
    end

    test "passes allow_fuse to container config" do
      Mimic.copy(Inkfish.Ittys)

      assignment = insert(:assignment)
      sub_upload = insert(:upload)
      sub = insert(:sub, assignment: assignment, upload: sub_upload)
      gc_upload = insert(:upload)

      grade_column =
        insert(:grade_column,
          kind: "script",
          assignment: assignment,
          upload: gc_upload,
          limits:
            "{\"cores\":1,\"megs\":2048,\"seconds\":300,\"allow_fuse\":true}"
        )

      insert(:grade, sub: sub, grade_column: grade_column)

      ag_job =
        insert(:ag_job, sub: sub, sub_id: sub.id)
        |> Repo.preload(sub: [:upload, grades: [grade_column: [:upload]]])

      expect(Ittys, :start, fn %Job{} = job ->
        run_task = Enum.find(job.tasks, fn t -> t.label == "Run container" end)
        assert run_task != nil
        {:run_container, conf} = run_task.action
        assert conf[:allow_fuse] == true
        assert conf[:megs] == 2048
        {:ok, job}
      end)

      Autograde.autograde(ag_job)

      verify!()
    end

    test "passes megs for memory limit" do
      Mimic.copy(Inkfish.Ittys)

      assignment = insert(:assignment)
      sub_upload = insert(:upload)
      sub = insert(:sub, assignment: assignment, upload: sub_upload)
      gc_upload = insert(:upload)

      grade_column =
        insert(:grade_column,
          kind: "script",
          assignment: assignment,
          upload: gc_upload,
          limits:
            "{\"cores\":1,\"megs\":4096,\"seconds\":300,\"allow_fuse\":false}"
        )

      insert(:grade, sub: sub, grade_column: grade_column)

      ag_job =
        insert(:ag_job, sub: sub, sub_id: sub.id)
        |> Repo.preload(sub: [:upload, grades: [grade_column: [:upload]]])

      expect(Ittys, :start, fn %Job{} = job ->
        run_task = Enum.find(job.tasks, fn t -> t.label == "Run container" end)
        assert run_task != nil
        {:run_container, conf} = run_task.action
        assert conf[:megs] == 4096
        {:ok, job}
      end)

      Autograde.autograde(ag_job)

      verify!()
    end
  end
end

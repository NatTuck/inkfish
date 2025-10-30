defmodule Inkfish.AgJobs.AutogradeTest do
  use Inkfish.DataCase, async: true

  import Mimic
  alias Inkfish.AgJobs.Autograde
  # alias Inkfish.AgJobs.AgJob
  alias Inkfish.Ittys
  alias Inkfish.Ittys.Job
  alias Inkfish.Repo
  # alias Inkfish.Sandbox.Containers

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
  end
end

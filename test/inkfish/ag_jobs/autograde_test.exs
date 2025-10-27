defmodule Inkfish.AgJobs.AutogradeTest do
  use Inkfish.DataCase, async: true

  import Mimic
  alias Inkfish.AgJobs.Autograde
  alias Inkfish.Ittys
  alias Inkfish.Ittys.Task
  alias Inkfish.Repo
  alias Inkfish.Sandbox.Containers

  import Inkfish.Factory

  describe "autograde/1" do
    test "constructs a task and passes it to Itty.start/1" do
      Mimic.copy(Inkfishs.Itty)
      Mimic.copy(Inkfish.Sandbox.Containers)

      # Setup: Create the necessary database records.
      # A grade needs a submission and a grade_column, which in turn
      # need uploads.
      assignment = insert(:assignment)
      sub_upload = insert(:upload)
      sub = insert(:sub, assignment: assignment, upload: sub_upload)
      gc_upload = insert(:upload)

      grade_column =
        insert(:grade_column, assignment: assignment, upload: gc_upload)

      grade =
        insert(:grade, sub: sub, grade_column: grade_column)
        |> Repo.preload(sub: :upload, grade_column: :upload)

      expect(Ittys, :start, fn %Task{} = task ->
        # Assert that the task passed to Itty contains the grade we created.
        assert task.grade.id == grade.id
        assert task.uuid == grade.log_uuid

        # The script and environment variables should be set correctly.
        assert task.cmd =~ "autograde-v3.pl"
        assert task.env["SUB"] =~ "unpacked"
        assert task.env["GRA"] =~ "unpacked"

        {:ok, task}
      end)

      expect(Containers, :create, fn conf ->
        assert is_list(conf.cmd)
      end)

      Autograde.autograde(grade)

      verify!()
    end
  end
end

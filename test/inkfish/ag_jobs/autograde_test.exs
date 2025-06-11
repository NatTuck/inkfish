defmodule Inkfish.AgJobs.AutogradeTest do
  use Inkfish.DataCase, async: true

  import Mimic
  alias Inkfish.AgJobs.Autograde
  alias Inkfish.Itty
  alias Inkfish.Itty.Task
  alias Inkfish.Repo

  import Inkfish.Factory

  describe "autograde/1" do
    test "constructs a task and passes it to Itty.start/1" do
      Mimic.copy(Inkfish.Itty)

      # Setup: Create the necessary database records.
      # A grade needs a submission and a grade_column, which in turn
      # need uploads.
      assignment = insert(:assignment)
      sub_upload = insert(:upload)
      sub = insert(:sub, assignment: assignment, upload: sub_upload)
      gc_upload = insert(:upload)
      grade_column = insert(:grade_column, assignment: assignment, upload: gc_upload)

      grade =
        insert(:grade, sub: sub, grade_column: grade_column)
        |> Repo.preload(sub: :upload, grade_column: :upload)

      # Mocking: Expect Itty.start/1 to be called. This uses the process-local
      # agent configured by `verify_mimic_on_exit!`.
      expect(Itty, :start, fn %Task{} = task ->
        # Assert that the task passed to Itty contains the grade we created.
        assert task.grade.id == grade.id
        assert task.uuid == grade.log_uuid

        # The script and environment variables should be set correctly.
        assert task.script =~ "simple-grade.pl"
        assert task.env["SUB"] =~ "unpacked"
        assert task.env["GRA"] =~ "unpacked"

        {:ok, task}
      end)

      # Execution: Call the function under test.
      Autograde.autograde(grade)

      verify!()
    end
  end
end

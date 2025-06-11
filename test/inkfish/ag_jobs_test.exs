defmodule Inkfish.AgJobsTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.AgJobs

  def ag_job_fixture() do
    insert(:ag_job)
  end

  describe "ag_jobs" do
    alias Inkfish.AgJobs.AgJob

    @invalid_attrs %{started_at: nil, dupkey: nil, prio: nil}

    test "list_ag_jobs/0 returns all ag_jobs" do
      ag_job = ag_job_fixture()
      assert Enum.map(AgJobs.list_ag_jobs(), & &1.dupkey) == [ag_job.dupkey]
    end

    test "get_ag_job!/1 returns the ag_job with given id" do
      ag_job = ag_job_fixture()
      assert AgJobs.get_ag_job!(ag_job.id).dupkey == ag_job.dupkey
    end

    test "create_ag_job/1 with valid data creates a ag_job" do
      valid_attrs = params_for(:ag_job)

      assert {:ok, %AgJob{} = ag_job} = AgJobs.create_ag_job(valid_attrs)
      assert ag_job.dupkey == valid_attrs.dupkey
      assert ag_job.prio == valid_attrs.prio
    end

    test "create_ag_job/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = AgJobs.create_ag_job(@invalid_attrs)
    end

    test "update_ag_job/2 with valid data updates the ag_job" do
      ag_job = ag_job_fixture()

      update_attrs = %{
        started_at: ~U[2025-06-08 18:16:00Z],
        dupkey: "some updated dupkey",
        prio: 43
      }

      assert {:ok, %AgJob{} = ag_job} =
               AgJobs.update_ag_job(ag_job, update_attrs)

      assert ag_job.started_at == ~U[2025-06-08 18:16:00Z]
      assert ag_job.dupkey == "some updated dupkey"
      assert ag_job.prio == 43
    end

    test "update_ag_job/2 with invalid data returns error changeset" do
      ag_job = ag_job_fixture()

      assert {:error, %Ecto.Changeset{}} =
               AgJobs.update_ag_job(ag_job, @invalid_attrs)

      assert ag_job.dupkey == AgJobs.get_ag_job!(ag_job.id).dupkey
    end

    test "delete_ag_job/1 deletes the ag_job" do
      ag_job = ag_job_fixture()
      assert {:ok, %AgJob{}} = AgJobs.delete_ag_job(ag_job)
      assert_raise Ecto.NoResultsError, fn -> AgJobs.get_ag_job!(ag_job.id) end
    end

    test "change_ag_job/1 returns a ag_job changeset" do
      ag_job = ag_job_fixture()
      assert %Ecto.Changeset{} = AgJobs.change_ag_job(ag_job)
    end
  end
end

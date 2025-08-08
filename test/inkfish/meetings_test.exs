defmodule Inkfish.MeetingsTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Meetings

  describe "meetings" do
    alias Inkfish.Meetings.Meeting

    @invalid_attrs %{started_at: nil}

    defp assert_datetimes_equal(dt1, dt2) do
      assert DateTime.compare(dt1, dt2) == :eq
    end

    defp assert_meetings_equal(m1, m2) do
      assert m1.id == m2.id
      assert_datetimes_equal(m1.started_at, m2.started_at)
      assert m1.course_id == m2.course_id
      assert m1.teamset_id == m2.teamset_id
    end

    test "list_meetings/1 returns all meetings for course" do
      meeting = insert(:meeting)
      meetings = Meetings.list_meetings(meeting.course)
      assert length(meetings) == 1
      assert_meetings_equal(hd(meetings), meeting)
    end

    test "get_meeting!/1 returns the meeting with given id" do
      meeting = insert(:meeting)
      retrieved = Meetings.get_meeting!(meeting.id)
      assert_meetings_equal(retrieved, meeting)
    end

    test "create_meeting/1 with valid data creates a meeting" do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      valid_attrs = %{
        started_at: ~U[2025-08-02 19:36:00Z],
        course_id: course.id,
        teamset_id: teamset.id,
        secret_code: "ABC123"
      }

      assert {:ok, %Meeting{} = meeting} = Meetings.create_meeting(valid_attrs)
      assert_datetimes_equal(meeting.started_at, ~U[2025-08-02 19:36:00Z])
      assert meeting.course_id == course.id
      assert meeting.teamset_id == teamset.id
    end

    test "create_meeting/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Meetings.create_meeting(@invalid_attrs)
    end

    test "update_meeting/2 with valid data updates the meeting" do
      meeting = insert(:meeting)
      update_attrs = %{started_at: ~U[2025-08-03 19:36:00Z]}

      assert {:ok, %Meeting{} = updated} =
               Meetings.update_meeting(meeting, update_attrs)

      assert_datetimes_equal(updated.started_at, ~U[2025-08-03 19:36:00Z])
    end

    test "update_meeting/2 with invalid data returns error changeset" do
      meeting = insert(:meeting)

      assert {:error, %Ecto.Changeset{}} =
               Meetings.update_meeting(meeting, @invalid_attrs)

      retrieved = Meetings.get_meeting!(meeting.id)
      assert_meetings_equal(meeting, retrieved)
    end

    test "delete_meeting/1 deletes the meeting" do
      meeting = insert(:meeting)
      assert {:ok, %Meeting{}} = Meetings.delete_meeting(meeting)

      assert_raise Ecto.NoResultsError, fn ->
        Meetings.get_meeting!(meeting.id)
      end
    end

    test "change_meeting/1 returns a meeting changeset" do
      meeting = insert(:meeting)
      assert %Ecto.Changeset{} = Meetings.change_meeting(meeting)
    end
  end
end

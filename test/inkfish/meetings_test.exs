defmodule Inkfish.MeetingsTest do
  use Inkfish.DataCase

  alias Inkfish.Meetings

  describe "meetings" do
    alias Inkfish.Meetings.Meeting

    import Inkfish.MeetingsFixtures

    @invalid_attrs %{started_at: nil}

    test "list_meetings/0 returns all meetings" do
      meeting = meeting_fixture()
      assert Meetings.list_meetings() == [meeting]
    end

    test "get_meeting!/1 returns the meeting with given id" do
      meeting = meeting_fixture()
      assert Meetings.get_meeting!(meeting.id) == meeting
    end

    test "create_meeting/1 with valid data creates a meeting" do
      valid_attrs = %{started_at: ~U[2025-08-02 19:36:00Z]}

      assert {:ok, %Meeting{} = meeting} = Meetings.create_meeting(valid_attrs)
      assert meeting.started_at == ~U[2025-08-02 19:36:00Z]
    end

    test "create_meeting/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Meetings.create_meeting(@invalid_attrs)
    end

    test "update_meeting/2 with valid data updates the meeting" do
      meeting = meeting_fixture()
      update_attrs = %{started_at: ~U[2025-08-03 19:36:00Z]}

      assert {:ok, %Meeting{} = meeting} = Meetings.update_meeting(meeting, update_attrs)
      assert meeting.started_at == ~U[2025-08-03 19:36:00Z]
    end

    test "update_meeting/2 with invalid data returns error changeset" do
      meeting = meeting_fixture()
      assert {:error, %Ecto.Changeset{}} = Meetings.update_meeting(meeting, @invalid_attrs)
      assert meeting == Meetings.get_meeting!(meeting.id)
    end

    test "delete_meeting/1 deletes the meeting" do
      meeting = meeting_fixture()
      assert {:ok, %Meeting{}} = Meetings.delete_meeting(meeting)
      assert_raise Ecto.NoResultsError, fn -> Meetings.get_meeting!(meeting.id) end
    end

    test "change_meeting/1 returns a meeting changeset" do
      meeting = meeting_fixture()
      assert %Ecto.Changeset{} = Meetings.change_meeting(meeting)
    end
  end
end

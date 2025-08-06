defmodule Inkfish.AttendancesTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Attendances

  describe "attendances" do
    alias Inkfish.Attendances.Attendance

    @invalid_attrs %{attended_at: nil}

    defp assert_datetimes_equal(dt1, dt2) do
      assert DateTime.compare(dt1, dt2) == :eq
    end

    defp assert_attendances_equal(a1, a2) do
      assert a1.id == a2.id
      assert_datetimes_equal(a1.attended_at, a2.attended_at)
      assert a1.meeting_id == a2.meeting_id
      assert a1.reg_id == a2.reg_id
    end

    test "list_attendances/0 returns all attendances" do
      attendance = insert(:attendance)
      attendances = Attendances.list_attendances()
      assert length(attendances) == 1
      assert_attendances_equal(hd(attendances), attendance)
    end

    test "get_attendance!/1 returns the attendance with given id" do
      attendance = insert(:attendance)
      retrieved = Attendances.get_attendance!(attendance.id)
      assert_attendances_equal(retrieved, attendance)
    end

    test "create_attendance/1 with valid data creates a attendance" do
      meeting = insert(:meeting)
      reg = insert(:reg)
      valid_attrs = %{attended_at: ~U[2025-08-02 22:55:00Z], meeting_id: meeting.id, reg_id: reg.id}

      assert {:ok, %Attendance{} = attendance} = Attendances.create_attendance(valid_attrs)
      assert_datetimes_equal(attendance.attended_at, ~U[2025-08-02 22:55:00Z])
      assert attendance.meeting_id == meeting.id
      assert attendance.reg_id == reg.id
    end

    test "create_attendance/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Attendances.create_attendance(@invalid_attrs)
    end

    test "update_attendance/2 with valid data updates the attendance" do
      attendance = insert(:attendance)
      update_attrs = %{attended_at: ~U[2025-08-03 22:55:00Z]}

      assert {:ok, %Attendance{} = updated} = Attendances.update_attendance(attendance, update_attrs)
      assert_datetimes_equal(updated.attended_at, ~U[2025-08-03 22:55:00Z])
    end

    test "update_attendance/2 with invalid data returns error changeset" do
      attendance = insert(:attendance)
      assert {:error, %Ecto.Changeset{}} = Attendances.update_attendance(attendance, @invalid_attrs)
      retrieved = Attendances.get_attendance!(attendance.id)
      assert_attendances_equal(attendance, retrieved)
    end

    test "delete_attendance/1 deletes the attendance" do
      attendance = insert(:attendance)
      assert {:ok, %Attendance{}} = Attendances.delete_attendance(attendance)
      assert_raise Ecto.NoResultsError, fn -> Attendances.get_attendance!(attendance.id) end
    end

    test "change_attendance/1 returns a attendance changeset" do
      attendance = insert(:attendance)
      assert %Ecto.Changeset{} = Attendances.change_attendance(attendance)
    end
  end
end

defmodule Inkfish.AttendancesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Inkfish.Attendances` context.
  """

  @doc """
  Generate a attendance.
  """
  def attendance_fixture(attrs \\ %{}) do
    {:ok, attendance} =
      attrs
      |> Enum.into(%{
        attended_at: ~U[2025-08-02 22:55:00Z]
      })
      |> Inkfish.Attendances.create_attendance()

    attendance
  end
end

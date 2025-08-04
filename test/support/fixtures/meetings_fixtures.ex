defmodule Inkfish.MeetingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Inkfish.Meetings` context.
  """

  @doc """
  Generate a meeting.
  """
  def meeting_fixture(attrs \\ %{}) do
    {:ok, meeting} =
      attrs
      |> Enum.into(%{
        started_at: ~U[2025-08-02 19:36:00Z]
      })
      |> Inkfish.Meetings.create_meeting()

    meeting
  end
end

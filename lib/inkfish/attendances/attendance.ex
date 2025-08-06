defmodule Inkfish.Attendances.Attendance do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  schema "attendances" do
    field :attended_at, :utc_datetime
    belongs_to :meeting, Inkfish.Meetings.Meeting
    belongs_to :reg, Inkfish.Users.Reg

    field :status, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  def parent(), do: :meeting
  def standard_preloads, do: [:reg]

  @doc false
  def changeset(attendance, attrs) do
    attrs =
      attrs
      |> Enum.map(fn {kk, vv} -> {to_string(kk), vv} end)
      |> Enum.into(%{})
      |> Map.update("attended_at", LocalTime.now(), fn dt ->
        if dt, do: LocalTime.from!(dt), else: nil
      end)

    attendance
    |> cast(attrs, [:attended_at, :meeting_id, :reg_id])
    |> validate_required([:attended_at, :meeting_id, :reg_id])
  end

  def minutes_late(%Attendance{} = at) do
    DateTime.diff(at.attended_at, at.meeting.started_at, :minute)
  end

  def put_status(%Attendance{} = at) do
    mins_late = minutes_late(at)

    cond do
      mins_late <= 6 ->
        %Attendance{at | status: "on time"}

      mins_late <= 17 ->
        %Attendance{at | status: "late"}

      mins_late <= 45 ->
        %Attendance{at | status: "very late"}

      true ->
        %Attendance{at | status: "too late"}
    end
  end
end

defmodule Inkfish.Attendances.Attendance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendances" do
    field :attended_at, :utc_datetime
    belongs_to :meeting, Inkfish.Meetings.Meeting
    belongs_to :reg, Inkfish.Users.Reg

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attendance, attrs) do
    attendance
    |> cast(attrs, [:attended_at, :meeting_id, :reg_id])
    |> validate_required([:attended_at, :meeting_id, :reg_id])
  end
end

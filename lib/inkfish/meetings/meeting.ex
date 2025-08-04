defmodule Inkfish.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :started_at, :utc_datetime
    field :secret_code, :string
    belongs_to :course, Inkfish.Courses.Course
    belongs_to :teamset, Inkfish.Teams.Teamset

    timestamps(type: :utc_datetime)
  end

  def parent(), do: :course
  def standard_preloads, do: [:teamset]

  @doc false
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:started_at, :course_id, :teamset_id, :secret_code])
    |> validate_required([:started_at, :course_id, :secret_code])
  end

  def gen_code() do
    :crypto.strong_rand_bytes(3)
    |> Base.encode16()
  end
end

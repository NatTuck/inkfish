defmodule Inkfish.Teams.Teamset do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "teamsets" do
    field :name, :string
    belongs_to :course, Inkfish.Courses.Course
    has_many :assignments, Inkfish.Assignments.Assignment
    has_many :teams, Inkfish.Teams.Team

    timestamps()
  end

  def parent(), do: :course

  @doc false
  def changeset(teamset, attrs) do
    teamset
    |> cast(attrs, [:name, :course_id])
    |> validate_required([:name, :course_id])
  end
end

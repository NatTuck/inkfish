defmodule Inkfish.Courses.Course do
  alias __MODULE__

  use Ecto.Schema
  import Ecto.Changeset

  alias Inkfish.Users.User

  @timestamps_opts [type: :utc_datetime]

  schema "courses" do
    field :name, :string
    field :start_date, :date
    field :footer, :string, default: ""
    field :grade_hide_days, :integer
    field :archived, :boolean
    field :sections, :string
    has_many :regs, Inkfish.Users.Reg
    has_many :join_reqs, Inkfish.JoinReqs.JoinReq
    has_many :buckets, Inkfish.Courses.Bucket
    has_many :teamsets, Inkfish.Teams.Teamset
    has_many :meetings, Inkfish.Meetings.Meeting
    belongs_to :solo_teamset, Inkfish.Teams.Teamset
    belongs_to :attendance_assignment, Inkfish.Assignments.Assignment

    field :instructor, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(course, attrs) do
    course
    |> cast(attrs, [
      :name,
      :start_date,
      :footer,
      :archived,
      :instructor,
      :solo_teamset_id,
      :sections,
      :attendance_assignment_id
    ])
    |> validate_required([:name, :start_date])
    |> validate_length(:name, min: 3)
  end

  def create_changeset(course, attrs) do
    changeset(course, attrs)
    |> validate_required([:instructor])
  end

  def instructor_login(course) do
    if instructor = get_field(course, :instructor) do
      User.normalize_email(instructor)
    else
      nil
    end
  end

  def list_sections(%Course{} = course) do
    (course.sections || "")
    |> String.replace(~r/,\s*/, ",")
    |> String.split(",", trim: true)
  end
end

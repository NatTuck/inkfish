defmodule Inkfish.Users.Reg do
  use Ecto.Schema
  import Ecto.Changeset
  # Added for Ecto.Query
  import Ecto.Query, warn: false

  @timestamps_opts [type: :utc_datetime]

  schema "regs" do
    field :is_grader, :boolean, default: false
    field :is_prof, :boolean, default: false
    field :is_staff, :boolean, default: false
    field :is_student, :boolean, default: false
    field :section, :string
    belongs_to :user, Inkfish.Users.User
    belongs_to :course, Inkfish.Courses.Course
    many_to_many :teams, Inkfish.Teams.Team, join_through: "team_members"
    has_many :subs, Inkfish.Subs.Sub
    has_many :grading_subs, Inkfish.Subs.Sub, foreign_key: :grader_id

    field :user_login, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(reg, attrs) do
    reg
    |> cast(attrs, [
      :user_id,
      :course_id,
      :is_student,
      :is_prof,
      :is_staff,
      :is_grader,
      :section
    ])
    |> validate_required([:user_id, :course_id])
    |> validate_not_student_and_staff()
    |> unique_constraint(:user_id, name: :regs_course_id_user_id_index)
  end

  def validate_not_student_and_staff(cset) do
    sp = get_field(cset, :is_student) && get_field(cset, :is_prof)
    ss = get_field(cset, :is_student) && get_field(cset, :is_staff)
    sg = get_field(cset, :is_student) && get_field(cset, :is_grader)

    if sp || ss || sg do
      add_error(cset, :is_student, "Students can't be staff")
    else
      cset
    end
  end

  @doc """
  Retrieves a user's registration for a specific course.
  """
  def get_by_user_and_course(user_id, course_id) do
    Inkfish.Repo.one(
      from(r in __MODULE__,
        where: r.user_id == ^user_id and r.course_id == ^course_id
      )
    )
  end
end

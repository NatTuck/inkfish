defmodule Inkfish.Courses do
  @moduledoc """
  The Courses context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Courses.Course
  alias Inkfish.Courses.Bucket
  alias Inkfish.Users
  alias Inkfish.Users.User
  alias Inkfish.Users.Reg
  alias Inkfish.Teams.Teamset

  @doc """
  Returns the list of courses.

  ## Examples

      iex> list_courses()
      [%Course{}, ...]

  """
  def list_courses do
    Repo.all(
      from cc in Course,
        order_by: [asc: cc.name]
    )
  end

  def list_courses_for_user(user) do
    regs =
      from reg in Reg,
        where: reg.user_id == ^user.id

    Repo.all(Course)
    |> Repo.preload(regs: regs)
  end

  @doc """
  Gets a single course.

  Raises `Ecto.NoResultsError` if the Course does not exist.

  ## Examples

      iex> get_course!(123)
      %Course{}

      iex> get_course!(456)
      ** (Ecto.NoResultsError)

  """
  def get_course!(id) do
    course = Repo.get!(Course, id)

    if course.solo_teamset_id == nil do
      %Course{} = course
      ts = Inkfish.Teams.create_solo_teamset!(course)
      %Course{course | solo_teamset_id: ts.id}
    else
      course
    end
  end

  def get_course(id) do
    try do
      get_course!(id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end

  def get_course_for_grading_tasks!(id) do
    Repo.one!(
      from cc in Course,
        where: cc.id == ^id,
        left_join: buckets in assoc(cc, :buckets),
        left_join: asgs in assoc(buckets, :assignments),
        left_join: gcols in assoc(asgs, :grade_columns),
        left_join: subs in assoc(asgs, :subs),
        left_join: grades in assoc(subs, :grades),
        left_join: ggcol in assoc(grades, :grade_column),
        left_join: grader in assoc(subs, :grader),
        left_join: user in assoc(grader, :user),
        preload: [
          buckets:
            {buckets,
             assignments:
               {asgs,
                grade_columns: gcols,
                subs:
                  {subs,
                   grades: {grades, grade_column: ggcol},
                   grader: {grader, user: user}}}}
        ]
    )
  end

  def get_course_for_staff_view!(id) do
    Repo.one!(
      from cc in Course,
        where: cc.id == ^id,
        left_join: buckets in assoc(cc, :buckets),
        left_join: bas in assoc(buckets, :assignments),
        left_join: gcols in assoc(bas, :grade_columns),
        left_join: teamsets in assoc(cc, :teamsets),
        left_join: tas in assoc(teamsets, :assignments),
        left_join: reqs in assoc(cc, :join_reqs),
        order_by: [asc: buckets.name, desc: bas.due, asc: bas.name],
        preload: [
          buckets: {buckets, assignments: {bas, grade_columns: gcols}},
          teamsets: {teamsets, assignments: tas},
          join_reqs: reqs
        ]
    )
  end

  def get_course_for_gradesheet!(id) do
    Repo.one!(
      from cc in Course,
        where: cc.id == ^id,
        left_join: buckets in assoc(cc, :buckets),
        left_join: asgs in assoc(buckets, :assignments),
        left_join: regs in assoc(cc, :regs),
        where: regs.is_student or is_nil(regs.is_student),
        left_join: student in assoc(regs, :user),
        left_join: teams in assoc(regs, :teams),
        left_join: subs in assoc(teams, :subs),
        where: subs.active or is_nil(subs.active),
        order_by: student.surname,
        preload: [
          regs: {regs, user: student, teams: {teams, subs: subs}},
          buckets: {buckets, assignments: asgs}
        ]
    )
  end

  def reload_course_for_student_view!(%Course{} = course, %Reg{} = reg) do
    # Confirm preload, should be no-op.
    reg = Users.preload_reg_teams!(reg)

    c_ts = reload_course_with_student_teams!(course, reg)
    c_bu = reload_course_with_student_subs!(course, reg)

    %Course{course | teamsets: c_ts.teamsets, buckets: c_bu.buckets}
  end

  def reload_course_with_student_teams!(%Course{} = course, %Reg{} = reg) do
    Repo.one!(
      from cc in Course,
        where: cc.id == ^course.id,
        left_join: teamsets in assoc(cc, :teamsets),
        left_join: ts_asgs in assoc(teamsets, :assignments),
        left_join: teams in assoc(teamsets, :teams),
        left_join: team_members in assoc(teams, :team_members),
        left_join: tm_reg in assoc(team_members, :reg),
        left_join: tm_user in assoc(tm_reg, :user),
        left_join: team_subs in assoc(teams, :subs),
        where: team_members.reg_id == ^reg.id or is_nil(team_members.id),
        where: teams.active or is_nil(teams.id),
        preload: [
          teamsets:
            {teamsets,
             teams:
               {teams,
                subs: team_subs,
                team_members: {team_members, reg: {tm_reg, user: tm_user}}},
             assignments: ts_asgs}
        ]
    )
  end

  def reload_course_with_student_subs!(%Course{} = course, %Reg{} = reg) do
    team_ids =
      reg.teams
      |> Enum.filter(& &1.active)
      |> Enum.map(& &1.id)

    Repo.one!(
      from cc in Course,
        where: cc.id == ^course.id,
        left_join: buckets in assoc(cc, :buckets),
        left_join: assignments in assoc(buckets, :assignments),
        left_join: subs in assoc(assignments, :subs),
        left_join: grades in assoc(subs, :grades),
        left_join: gcols in assoc(assignments, :grade_columns),
        where: subs.team_id in ^team_ids or is_nil(subs.id),
        where: subs.active or is_nil(subs.id),
        order_by: [asc: buckets.name, asc: assignments.due],
        preload: [
          buckets:
            {buckets,
             assignments: {
               assignments,
               subs: subs, grade_columns: gcols
             }}
        ]
    )
  end

  def get_teams_for_student!(%Course{} = course, %Reg{} = reg) do
    Enum.map(course.teamsets, fn ts ->
      team =
        Enum.find(reg.teams, fn team ->
          team.active && team.teamset_id == ts.id
        end)

      if team do
        {ts.id, team}
      else
        {:ok, team} = Inkfish.Teams.get_active_team(ts, reg)
        team = Repo.preload(team, :subs)
        {ts.id, team}
      end
    end)
    |> Enum.into(%{})
  end

  def get_course_by_name(name) do
    course = Repo.get_by(Course, name: name)

    if course do
      get_course_for_staff_view!(course)
    else
      nil
    end
  end

  @doc """
  Creates a course.

  ## Examples

      iex> create_course(%{field: value})
      {:ok, %Course{}}

      iex> create_course(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_course(attrs \\ %{}) do
    course = Course.changeset(%Course{}, attrs)
    instructor = Course.instructor_login(course)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:course, course)
      |> course_add_instructor(instructor)
      |> course_add_solo_teamset()
      |> Repo.transaction()

    case result do
      {:ok, %{course_w_ts: course}} ->
        {:ok, course}

      {:error, :course, cset, _} ->
        {:error, cset}

      {:error, :reg, cset, _} ->
        cset =
          Ecto.Changeset.add_error(cset, :instructor, "instructor reg failed")

        {:error, cset}
    end
  end

  def course_add_instructor(tx, nil), do: tx

  def course_add_instructor(tx, instructor) do
    email = User.extract_email(instructor)
    user = Users.get_user_by_email!(email)

    op = fn %{course: course} ->
      Reg.changeset(%Reg{}, %{
        user_id: user.id,
        course_id: course.id,
        is_prof: true
      })
    end

    Ecto.Multi.insert(tx, :reg, op,
      on_conflict: :replace_all,
      conflict_target: [:user_id, :course_id]
    )
  end

  def course_add_solo_teamset(tx) do
    tx =
      Ecto.Multi.insert(tx, :tset, fn %{course: course} ->
        attrs = %{name: "Solo Work", course_id: course.id}
        Teamset.changeset(%Teamset{}, attrs)
      end)

    Ecto.Multi.update(tx, :course_w_ts, fn %{course: course, tset: tset} ->
      Course.changeset(course, %{solo_teamset_id: tset.id})
    end)
  end

  @doc """
  Updates a course.

  ## Examples

      iex> update_course(course, %{field: new_value})
      {:ok, %Course{}}

      iex> update_course(course, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_course(%Course{} = course, attrs) do
    course = Course.changeset(course, attrs)
    instructor = Course.instructor_login(course)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:course, course)
      |> course_add_instructor(instructor)
      |> Repo.transaction()

    case result do
      {:ok, %{course: course}} ->
        {:ok, course}
        |> Repo.Cache.updated()

      {:error, :course, cset, _} ->
        {:error, cset}

      {:error, :reg, cset, _} ->
        cset =
          Ecto.Changeset.add_error(cset, :instructor, "instructor reg failed")

        {:error, cset}
    end
  end

  @doc """
  Deletes a Course.

  ## Examples

      iex> delete_course(course)
      {:ok, %Course{}}

      iex> delete_course(course)
      {:error, %Ecto.Changeset{}}

  """
  def delete_course(%Course{} = course) do
    Repo.delete(course)
    |> Repo.Cache.updated()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking course changes.

  ## Examples

      iex> change_course(course)
      %Ecto.Changeset{source: %Course{}}

  """
  def change_course(%Course{} = course) do
    Course.changeset(course, %{})
  end

  def get_one_course_prof(%Course{} = course) do
    Repo.one(
      from uu in User,
        join: rr in Reg,
        on: rr.user_id == uu.id,
        where: rr.course_id == ^course.id and rr.is_prof,
        limit: 1
    )
  end

  def list_course_graders(%Course{} = course) do
    list_course_graders(course.id)
  end

  def list_course_graders(course_id) do
    Repo.all(
      from reg in Reg,
        inner_join: user in assoc(reg, :user),
        where: reg.course_id == ^course_id,
        where: reg.is_grader,
        preload: [user: user]
    )
  end

  @doc """
  Returns the list of buckets.

  ## Examples

      iex> list_buckets()
      [%Bucket{}, ...]

  """
  def list_buckets do
    Repo.all(Bucket)
  end

  def list_buckets(course_id) do
    Repo.all(
      from bb in Bucket,
        where: bb.course_id == ^course_id
    )
  end

  @doc """
  Gets a single bucket.

  Raises `Ecto.NoResultsError` if the Bucket does not exist.

  ## Examples

      iex> get_bucket!(123)
      %Bucket{}

      iex> get_bucket!(456)
      ** (Ecto.NoResultsError)

  """
  def get_bucket!(id), do: Repo.get!(Bucket, id)
  def get_bucket(id), do: Repo.get(Bucket, id)

  @doc """
  Creates a bucket.

  ## Examples

      iex> create_bucket(%{field: value})
      {:ok, %Bucket{}}

      iex> create_bucket(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_bucket(attrs \\ %{}) do
    %Bucket{}
    |> Bucket.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a bucket.

  ## Examples

      iex> update_bucket(bucket, %{field: new_value})
      {:ok, %Bucket{}}

      iex> update_bucket(bucket, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_bucket(%Bucket{} = bucket, attrs) do
    bucket
    |> Bucket.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  @doc """
  Deletes a Bucket.

  ## Examples

      iex> delete_bucket(bucket)
      {:ok, %Bucket{}}

      iex> delete_bucket(bucket)
      {:error, %Ecto.Changeset{}}

  """
  def delete_bucket(%Bucket{} = bucket) do
    Repo.delete(bucket)
    |> Repo.Cache.updated()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bucket changes.

  ## Examples

      iex> change_bucket(bucket)
      %Ecto.Changeset{source: %Bucket{}}

  """
  def change_bucket(%Bucket{} = bucket) do
    Bucket.changeset(bucket, %{})
  end
end

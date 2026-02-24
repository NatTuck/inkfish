defmodule Inkfish.Assignments do
  @moduledoc """
  The Assignments context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo
  alias Inkfish.Repo.Cache

  alias Inkfish.Assignments.Assignment
  alias Inkfish.Courses.Bucket
  alias Inkfish.Subs.Sub
  alias Inkfish.Users.Reg
  alias Inkfish.Teams.Team

  @doc """
  Returns the list of assignments.

  ## Examples

      iex> list_assignments()
      [%Assignment{}, ...]

  """
  def list_assignments do
    Repo.all(Assignment)
  end

  @doc """
  Gets a single assignment.

  Raises `Ecto.NoResultsError` if the Assignment does not exist.

  ## Examples

      iex> get_assignment!(123)
      %Assignment{}

      iex> get_assignment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_assignment!(id) do
    Repo.one!(
      from as in Assignment,
        where: as.id == ^id,
        left_join: teamset in assoc(as, :teamset),
        left_join: grade_columns in assoc(as, :grade_columns),
        left_join: starter in assoc(as, :starter_upload),
        left_join: solution in assoc(as, :solution_upload),
        preload: [
          teamset: teamset,
          grade_columns: grade_columns,
          starter_upload: starter,
          solution_upload: solution
        ]
    )
  end

  def list_subs_for_reg(as_id, %Reg{} = reg),
    do: list_subs_for_reg(as_id, reg.id)

  def list_subs_for_reg(as_id, reg_id) do
    teams =
      Repo.all(
        from tt in Team,
          inner_join: teamset in assoc(tt, :teamset),
          left_join: asgs in assoc(teamset, :assignments),
          left_join: members in assoc(tt, :team_members),
          where: members.reg_id == ^reg_id,
          where: asgs.id == ^as_id
      )

    team_ids = Enum.map(teams, & &1.id)

    Repo.all(
      from sub in Sub,
        where: sub.assignment_id == ^as_id,
        where: sub.reg_id == ^reg_id or sub.team_id in ^team_ids,
        left_join: grades in assoc(sub, :grades),
        order_by: [desc: :inserted_at],
        preload: [grades: grades]
    )
  end

  def list_active_subs(%Assignment{} = as) do
    Repo.all(
      from sub in Sub,
        where: sub.assignment_id == ^as.id,
        where: sub.active,
        left_join: grades in assoc(sub, :grades),
        left_join: reg in assoc(sub, :reg),
        left_join: user in assoc(reg, :user),
        left_join: gcol in assoc(grades, :grade_column),
        preload: [grades: {grades, grade_column: gcol}, reg: {reg, user: user}]
    )
  end

  def get_assignment_for_staff!(id) do
    Repo.one!(
      from as in Assignment,
        where: as.id == ^id,
        left_join: teamset in assoc(as, :teamset),
        left_join: grade_columns in assoc(as, :grade_columns),
        left_join: starter in assoc(as, :starter_upload),
        left_join: solution in assoc(as, :solution_upload),
        preload: [
          teamset: teamset,
          grade_columns: grade_columns,
          starter_upload: starter,
          solution_upload: solution
        ]
    )
  end

  def get_assignment_path(id) do
    Cache.get(Assignment, id)
  end

  def get_assignment_for_grading_tasks!(id) do
    Repo.one!(
      from as in Assignment,
        where: as.id == ^id,
        left_join: bucket in assoc(as, :bucket),
        left_join: grade_columns in assoc(as, :grade_columns),
        left_join: subs in assoc(as, :subs),
        left_join: grades in assoc(subs, :grades),
        left_join: ggcol in assoc(grades, :grade_column),
        left_join: reg in assoc(subs, :reg),
        left_join: user in assoc(reg, :user),
        left_join: grader in assoc(subs, :grader),
        left_join: guser in assoc(grader, :user),
        where: subs.active,
        where: reg.is_student,
        preload: [
          bucket: bucket,
          grade_columns: grade_columns,
          subs: {
            subs,
            reg: {reg, user: user},
            grader: {grader, user: guser},
            grades: {grades, grade_column: ggcol}
          }
        ]
    )
  end

  def preload_uploads(%Assignment{} = asg) do
    Repo.preload(asg, [:starter_upload, :solution_upload])
  end

  @doc """
  Creates a assignment.

  ## Examples

      iex> create_assignment(%{field: value})
      {:ok, %Assignment{}}

      iex> create_assignment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_assignment(attrs \\ %{}) do
    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a assignment.

  ## Examples

      iex> update_assignment(assignment, %{field: new_value})
      {:ok, %Assignment{}}

      iex> update_assignment(assignment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_assignment(%Assignment{} = assignment, attrs) do
    assignment
    |> Assignment.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  def update_assignment_points!(%Assignment{} = as) do
    update_assignment_points!(as.id)
  end

  def update_assignment_points!(as_id) do
    rv =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:as0, fn _, _ ->
        as =
          Repo.one(
            from as in Assignment,
              where: as.id == ^as_id,
              left_join: gcs in assoc(as, :grade_columns),
              preload: [grade_columns: gcs]
          )

        {:ok, as}
      end)
      |> Ecto.Multi.update(:as1, fn %{as0: as} ->
        points =
          Enum.reduce(as.grade_columns, Decimal.new("0.0"), fn gc, acc ->
            Decimal.add(acc, gc.points)
          end)

        Ecto.Changeset.change(as, points: points)
      end)
      |> Repo.transaction()

    :ok = Repo.Cache.drop(Assignment, as_id)

    rv
  end

  @doc """
  Deletes a Assignment.

  ## Examples

      iex> delete_assignment(assignment)
      {:ok, %Assignment{}}

      iex> delete_assignment(assignment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_assignment(%Assignment{} = assignment) do
    Repo.delete(assignment)
    |> Repo.Cache.updated()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking assignment changes.

  ## Examples

      iex> change_assignment(assignment)
      %Ecto.Changeset{source: %Assignment{}}

  """
  def change_assignment(%Assignment{} = assignment) do
    Assignment.changeset(assignment, %{})
  end

  def next_due(course_id, _user_id) do
    Repo.one(
      from as in Assignment,
        inner_join: bucket in assoc(as, :bucket),
        where: bucket.course_id == ^course_id,
        where: as.due > fragment("now()::timestamp"),
        limit: 1
    )
  end

  @doc """
  Creates a fake sub for each team in the associated teamset,
  containing a single text file for grading.
  """
  def create_fake_subs!(as, owner) do
    {:ok, upload} = Inkfish.Uploads.create_fake_upload(owner)
    teams = Inkfish.Teams.list_teams(as.teamset_id)

    Enum.each(teams, fn team ->
      submitter = hd(team.regs)

      attrs = %{
        assignment_id: as.id,
        reg_id: submitter.id,
        team_id: team.id,
        upload_id: upload.id,
        hours_spent: "0.0"
      }

      {:ok, _sub} = Inkfish.Subs.create_sub(attrs)
    end)
  end

  @doc """
  Assigns staff grading tasks for submissions to this
  assignment.
  """
  def assign_grading_tasks(as = %Assignment{}) do
    assign_grading_tasks(as.id)
  end

  def assign_grading_tasks(_as_id) do
    # _as = get_assignment_path!(as_id)
    raise "Actually do thing"

    # FIXME: Actually do thing
    # Remove grading tasks for inactive subs.
    # GradingTasks.unassign_inactive_subs(as)

    # Process active subs.
    # GradingTasks.assign_grading_tasks(as)
  end

  def list_grading_tasks(as) do
    asg = get_assignment_for_grading_tasks!(as.id)

    asg.subs
    |> Enum.filter(fn sub ->
      grade =
        Enum.find(sub.grades, fn gr ->
          gr.grade_column.kind == "feedback"
        end)

      grade == nil || grade.score == nil
    end)
    |> Enum.map(fn sub ->
      %{sub | assignment: as}
    end)
  end

  def list_past_assignments_with_ungraded_subs(course_ids)
      when is_list(course_ids) do
    now = NaiveDateTime.utc_now()
    four_days_ago = NaiveDateTime.add(now, -4 * 24 * 3600, :second)

    assignment_rows =
      Repo.all(
        from as in Assignment,
          inner_join: bucket in assoc(as, :bucket),
          where: bucket.course_id in ^course_ids,
          where: as.due < ^now,
          select: %{
            id: as.id,
            name: as.name,
            due: as.due,
            bucket_name: bucket.name,
            course_id: bucket.course_id
          }
      )

    assignment_data =
      Enum.map(assignment_rows, fn %{due: due} = row ->
        asg =
          Repo.get!(Assignment, row.id)
          |> Repo.preload([:grade_columns, subs: :grades])

        required_kinds = ~w(feedback number)

        required_gcol_ids =
          Enum.filter(asg.grade_columns, fn gc -> gc.kind in required_kinds end)
          |> Enum.map(& &1.id)
          |> MapSet.new()

        total_count =
          Enum.count(asg.subs, fn s -> s.active end)

        graded_count =
          Enum.count(asg.subs, fn s ->
            s.active &&
              Enum.all?(required_gcol_ids, fn gcol_id ->
                Enum.any?(s.grades, fn g ->
                  g.grade_column_id == gcol_id && g.score != nil
                end)
              end)
          end)

        %{
          id: row.id,
          name: row.name,
          due: due,
          bucket_name: row.bucket_name,
          course_id: row.course_id,
          total_count: total_count,
          graded_count: graded_count,
          ungraded_count: total_count - graded_count,
          overdue: NaiveDateTime.compare(due, four_days_ago) == :lt
        }
      end)

    Enum.filter(assignment_data, fn row ->
      row.ungraded_count > 0 or row.total_count == 0
    end)
  end

  def list_past_assignments_with_ungraded_subs(_), do: []

  def list_all_buckets_with_upcoming(course_ids, limit \\ 2)

  def list_all_buckets_with_upcoming(course_ids, limit)
      when is_list(course_ids) do
    now = NaiveDateTime.utc_now()

    buckets =
      Repo.all(
        from b in Bucket, where: b.course_id in ^course_ids, order_by: b.name
      )

    bucket_map =
      Enum.map(buckets, fn bucket ->
        assignments =
          Repo.all(
            from as in Assignment,
              where: as.bucket_id == ^bucket.id,
              where: as.due > ^now,
              order_by: [asc: as.due],
              limit: ^limit
          )

        upcoming =
          Enum.map(assignments, fn %{due: due} = as ->
            %{
              id: as.id,
              name: as.name,
              due: due
            }
          end)

        {bucket.name, upcoming}
      end)

    Enum.into(bucket_map, %{})
  end

  def list_all_buckets_with_upcoming(_, _), do: %{}
end

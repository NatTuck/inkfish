defmodule Inkfish.Subs do
  @moduledoc """
  The Subs context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Subs.Sub
  alias Inkfish.Users.Reg
  alias Inkfish.Teams
  alias Inkfish.Teams.Team
  alias Inkfish.Grades
  alias Inkfish.Grades.GradeColumn
  alias Inkfish.Grades.Grade
  alias Inkfish.Uploads

  def make_zero_sub(as) do
    %Sub{
      active: true,
      assignment: as,
      score: Decimal.new("0.0")
    }
  end

  @doc """
  Returns the list of subs.

  ## Examples

      iex> list_subs()
      [%Sub{}, ...]

  """
  def list_subs() do
    Repo.all(Sub)
  end

  def list_subs_for_reg(%Reg{} = reg) do
    list_subs_for_reg(reg.id)
  end

  def list_subs_for_reg(reg_id) do
    Repo.all(
      from(sub in Sub,
        inner_join: team in assoc(sub, :team),
        inner_join: tregs in assoc(team, :regs),
        where: tregs.id == ^reg_id,
        order_by: [desc: sub.inserted_at]
      )
    )
  end

  def list_subs_for_api(asg_id, reg_id, page \\ 0) do
    offset = 100 * page

    Repo.all(
      from(sub in Sub,
        where: sub.assignment_id == ^asg_id,
        order_by: [desc: sub.inserted_at],
        limit: 100,
        offset: ^offset,
        where: sub.reg_id == ^reg_id,
        preload: [:upload]
      )
    )
  end

  def list_subs_for_staff_api(asg_id, page \\ 0) do
    offset = 100 * page

    Repo.all(
      from(sub in Sub,
        where: sub.assignment_id == ^asg_id,
        order_by: [desc: sub.inserted_at],
        limit: 100,
        offset: ^offset,
        where: sub.active,
        preload: [:upload, reg: [:user]]
      )
    )
  end

  def active_sub_for_reg(asg_id, %Reg{} = reg) do
    active_sub_for_reg(asg_id, reg.id)
  end

  def active_sub_for_reg(asg_id, reg_id) do
    Repo.one(
      from(sub in Sub,
        where: sub.reg_id == ^reg_id,
        where: sub.assignment_id == ^asg_id,
        where: sub.active,
        limit: 1
      )
    )
  end

  def active_sub_for_team(asg_id, team_id) do
    Repo.one(
      from(sub in Sub,
        where: sub.team_id == ^team_id,
        where: sub.assignment_id == ^asg_id,
        where: sub.active,
        limit: 1
      )
    )
  end

  def count_subs_for_grader(asgs, reg) do
    as_ids = Enum.map(asgs, & &1.id)

    Repo.one(
      from(sub in Sub,
        where: sub.grader_id == ^reg.id,
        where: sub.assignment_id in ^as_ids,
        where: sub.active,
        select: count(sub.id)
      )
    )
  end

  @doc """
  Gets a single sub.

  Raises `Ecto.NoResultsError` if the Sub does not exist.

  ## Examples

      iex> get_sub!(123)
      %Sub{}

      iex> get_sub!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sub(id) do
    Repo.one(
      from(sub in Sub,
        where: sub.id == ^id,
        inner_join: upload in assoc(sub, :upload),
        inner_join: reg in assoc(sub, :reg),
        inner_join: user in assoc(reg, :user),
        inner_join: team in assoc(sub, :team),
        inner_join: as in assoc(sub, :assignment),
        inner_join: bucket in assoc(as, :bucket),
        inner_join: course in assoc(bucket, :course),
        left_join: grader in assoc(sub, :grader),
        left_join: gruser in assoc(grader, :user),
        left_join: grades in assoc(sub, :grades),
        left_join: lcs in assoc(grades, :line_comments),
        left_join: gc in assoc(grades, :grade_column),
        preload: [
          upload: upload,
          team: team,
          grades: {grades, grade_column: gc, line_comments: lcs},
          reg: {reg, user: user},
          grader: {grader, user: gruser},
          assignment: {as, bucket: {bucket, course: course}}
        ]
      )
    )
  end

  def get_sub!(id) do
    if sub = get_sub(id) do
      sub
    else
      raise "Sub not found"
    end
  end

  def get_sub_with_grades!(id) do
    Repo.one!(
      from(sub in Sub,
        where: sub.id == ^id,
        inner_join: as in assoc(sub, :assignment),
        left_join: agcols in assoc(as, :grade_columns),
        left_join: grades in assoc(sub, :grades),
        left_join: gc in assoc(grades, :grade_column),
        preload: [
          grades: {grades, grade_column: gc},
          assignment: {as, grade_columns: agcols}
        ]
      )
    )
  end

  def preload_upload(%Sub{} = sub) do
    Repo.preload(sub, [:upload])
  end

  @doc """
  Creates a sub.

  ## Examples

      iex> create_sub(%{field: value})
      {:ok, %Sub{}}

      iex> create_sub(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sub(attrs \\ %{}) do
    result =
      %Sub{}
      |> Sub.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, sub} ->
        set_one_sub_active!(sub)

        if has_autograders?(sub) do
          autograde!(sub)
        end

        sub = Repo.preload(sub, [:upload])

        {:ok, sub}

      error ->
        error
    end
  end

  def create_sub_with_upload(sub_attrs, upload_attrs) do
    upload_attrs = Map.put(upload_attrs, "kind", "sub")

    Repo.transact(fn ->
      with {:ok, upload} = Uploads.create_upload(upload_attrs) do
        sub_attrs
        |> Map.put("upload_id", upload.id)
        |> create_sub()
      end
    end)
  end

  def has_autograders?(sub) do
    asg = Inkfish.Assignments.get_assignment!(sub.assignment_id)

    Enum.any?(asg.grade_columns, fn gc ->
      gc.kind == "script"
    end)
  end

  def get_script_grades(%Sub{} = sub) do
    sub = Repo.preload(sub, grades: :grade_column)

    Enum.filter(sub.grades, fn gr ->
      gr.grade_column.kind == "script"
    end)
  end

  def get_script_grades(sub_id) do
    Repo.get!(Sub, sub_id)
    |> get_script_grades()
  end

  def reset_script_grades(%Sub{} = sub) do
    sub =
      Repo.preload(sub,
        grades: [:grade_column],
        assignment: [:grade_columns],
        upload: []
      )

    Enum.each(get_script_grades(sub), fn gr ->
      Grades.delete_grade(gr)
    end)

    get_or_create_script_grades(sub)
  end

  def reset_script_grades(sub_id) do
    Repo.get!(Sub, sub_id)
    |> reset_script_grades()
  end

  def get_or_create_script_grades(%Sub{} = sub) do
    sub = get_sub_with_grades!(sub.id)

    script_cols =
      sub.assignment.grade_columns
      |> Enum.filter(fn gcol ->
        gcol.kind == "script"
      end)

    Enum.map(script_cols, fn gcol ->
      get_or_create_script_grade(sub, gcol)
    end)
  end

  def get_or_create_script_grade(%Sub{} = sub, %GradeColumn{} = gc) do
    grade1 =
      Enum.find(sub.grades, fn gr ->
        gr.grade_column_id == gc.id
      end)

    if grade1 do
      if is_nil(grade1.log_uuid) do
        %Grade{grade1 | sub: sub, grade_column: gc, log_uuid: "HUH?"}
      else
        %Grade{grade1 | sub: sub, grade_column: gc}
      end
    else
      {:ok, gr} = Grades.create_autograde(sub.id, gc.id)
      %Grade{gr | sub: sub, grade_column: gc}
    end
  end

  def autograde!(sub) do
    reset_script_grades(sub)

    Inkfish.AgJobs.create_ag_job(sub)
    Inkfish.AgJobs.Server.poll()
  end

  def set_one_sub_active!(new_sub) do
    prev = active_sub_for_team(new_sub.assignment_id, new_sub.team_id)
    # If the active sub has been graded or late penalty ignored, we keep it.
    if prev && (prev.score || prev.ignore_late_penalty) do
      set_sub_active!(prev)
    else
      set_sub_active!(new_sub)
    end
  end

  def set_sub_active!(new_sub) do
    asg_id = new_sub.assignment_id
    team_id = new_sub.team_id
    team = Teams.get_team!(team_id)

    # This should be the active sub for each member of the
    # team.

    member_ids = Enum.map(team.team_members, & &1.reg_id)

    teams =
      Repo.all(
        from(tt in Team,
          left_join: members in assoc(tt, :team_members),
          where: members.reg_id in ^member_ids
        )
      )

    team_ids = Enum.map(teams, & &1.id)

    subs =
      from(sub in Sub,
        where: sub.assignment_id == ^asg_id,
        where: sub.team_id in ^team_ids
      )

    {:ok, _} =
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(:subs, subs, set: [active: false])
      |> Ecto.Multi.update(:sub, Sub.make_active(new_sub))
      |> Repo.transaction()
  end

  @doc """
  Updates a sub.

  ## Examples

      iex> update_sub(sub, %{field: new_value})
      {:ok, %Sub{}}

      iex> update_sub(sub, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sub(%Sub{} = sub, attrs) do
    sub
    |> Sub.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  def update_sub_grader(%Sub{} = sub, grader_id) do
    sub
    |> Sub.change_grader(grader_id)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  def update_sub_ignore_late(%Sub{} = sub, attrs) do
    {:ok, sub} =
      sub
      |> Sub.change_ignore_late(attrs)
      |> Repo.update()
      |> Repo.Cache.updated()

    # if sub.ignore_late_penalty do
    #  set_sub_active!(sub)
    # end

    calc_sub_score!(sub.id)
    sub
  end

  def get_sub_for_calc_score!(sub_id) do
    Repo.one!(
      from(sub in Sub,
        inner_join: as in assoc(sub, :assignment),
        left_join: grade_columns in assoc(as, :grade_columns),
        left_join: grades in assoc(sub, :grades),
        preload: [
          assignment: {as, grade_columns: grade_columns},
          grades: grades
        ],
        where: sub.id == ^sub_id
      )
    )
  end

  def calc_score_and_late_penalty(sub) do
    scores =
      Enum.map(sub.assignment.grade_columns, fn gdr ->
        grade = Enum.find(sub.grades, &(&1.grade_column_id == gdr.id))
        grade && grade.score
      end)

    if Enum.all?(scores, &(!is_nil(&1))) do
      late_penalty = late_penalty(sub)

      total =
        Enum.reduce(scores, Decimal.new("0"), &Decimal.add/2)
        |> apply_penalty(late_penalty)

      {total, late_penalty}
    else
      {nil, nil}
    end
  end

  def calc_sub_score!(sub_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:sub0, fn _, _ ->
      {:ok, get_sub_for_calc_score!(sub_id)}
    end)
    |> Ecto.Multi.update(:sub, fn %{sub0: sub} ->
      {score, late_penalty} = calc_score_and_late_penalty(sub)
      Ecto.Changeset.change(sub, score: score, late_penalty: late_penalty)
    end)
    |> Repo.transaction()
  end

  def hours_late(sub) do
    due = Inkfish.LocalTime.from_naive!(sub.assignment.due)
    subed = sub.inserted_at
    seconds_late = DateTime.diff(subed, due)
    hours_late = floor((seconds_late + 3599) / 3600)

    if hours_late > 0 do
      hours_late
    else
      0
    end
  end

  def apply_penalty(score0, penalty) do
    score1 = Decimal.sub(score0, penalty)

    if Decimal.compare(score1, Decimal.new("0")) == :lt do
      0
    else
      score1
    end
  end

  def late_penalty(sub) do
    if sub.ignore_late_penalty do
      0
    else
      points_avail =
        Inkfish.Assignments.Assignment.assignment_total_points(sub.assignment)

      if sub.assignment.hard_deadline do
        if hours_late(sub) > 0 do
          points_avail
        else
          0
        end
      else
        penalty_frac = Decimal.from_float(hours_late(sub) / 100.0)
        Decimal.mult(points_avail, penalty_frac)
      end
    end
  end

  @doc """
  Deletes a Sub.

  ## Examples

      iex> delete_sub(sub)
      {:ok, %Sub{}}

      iex> delete_sub(sub)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sub(%Sub{} = _sub) do
    # Repo.delete(sub)
    # |> Repo.Cache.updated()
    {:error, "We don't delete subs"}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sub changes.

  ## Examples

      iex> change_sub(sub)
      %Ecto.Changeset{source: %Sub{}}

  """
  def change_sub(%Sub{} = sub) do
    Sub.changeset(sub, %{})
  end

  def read_sub_data(%Sub{} = sub) do
    files = Inkfish.Uploads.Data.read_data(sub.upload)

    %{
      sub_id: sub.id,
      files: files
    }
  end

  def read_sub_data(sub_id) do
    read_sub_data(get_sub!(sub_id))
  end

  def save_sub_dump!(sub_id) do
    sub = Inkfish.Subs.get_sub!(sub_id)

    json =
      Sub.to_map(sub)
      |> Jason.encode!(pretty: true)

    Inkfish.Subs.save_sub_dump!(sub.id, json)
  end

  def save_sub_dump!(sub_id, json) do
    sub = get_sub!(sub_id)
    base = Inkfish.Uploads.Upload.upload_dir(sub.upload_id)
    path = Path.join(base, "dump.json")
    File.write!(path, json)
    # IO.inspect({"Data for sub dumped", sub.id, path})
  end
end

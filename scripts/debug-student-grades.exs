defmodule Debug do
  alias Inkfish.Users
  alias Inkfish.Courses
  alias Inkfish.Subs
  alias Inkfish.Assignments
  alias Inkfish.Assignments.Assignment
  alias Inkfish.Teams

  def run() do
    student_id = 77
    course_id = 7

    user = Users.get_user!(student_id)
    course = Courses.get_course!(course_id)

    {:ok, reg} = Users.find_reg(user, course)
    reg = Users.preload_reg_teams!(reg)

    course = course
      |> Courses.add_solo_team(reg)
      |> Courses.reload_course_for_student_view!(reg)
      
    totals = bucket_totals(course.buckets, reg)

    IO.inspect(totals)

    :ok
  end

  def bucket_totals(buckets, reg) do
    for bucket <- buckets do
      base = {Decimal.new("0.0"), Decimal.new("0.0")}

      {s, p} =
        Enum.reduce(bucket.assignments, base, fn as, {s, p} ->
          if is_nil(as) do
            raise "Nil assignment"
          end

          {:ok, team} = Teams.get_active_team(as, reg)
          zero_sub = Subs.make_zero_sub(as)
          sub = Enum.find(as.subs, zero_sub, & &1.active)
          real_sub = Subs.active_sub_for_team(as.id, team.id) || zero_sub
          score = sub.score || Decimal.new("0.0")
          weight = fix_weight(as.weight)
          points = Assignment.assignment_total_points(as)
          frac = Decimal.div(Decimal.mult(weight, score), fix_weight(points))
          IO.inspect({as.id, as.name, sub.id, real_sub.id, frac, points})
          {Decimal.add(s, frac), Decimal.add(p, weight)}
        end)

      p = fix_weight(p)
      pct = Decimal.mult(Decimal.div(s, p), Decimal.new("100.0"))

      # IO.inspect({:bucket, bucket, s, p})

      {bucket.id, pct}
    end
    |> Enum.into(%{})
  end

  defp fix_weight(ww) do
    if Decimal.compare(ww, Decimal.new(0)) == :gt do
      ww
    else
      Decimal.new(1)
    end
  end

end

Debug.run()


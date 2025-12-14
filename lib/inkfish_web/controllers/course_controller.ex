defmodule InkfishWeb.CourseController do
  use InkfishWeb, :controller

  alias Inkfish.Courses
  alias Inkfish.Subs
  alias Inkfish.Users
  alias Inkfish.Assignments.Assignment

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem,
       [course: "id"]
       when action not in [:index]

  plug Plugs.RequireReg
       when action not in [:index]

  def index(conn, _params) do
    courses = Courses.list_courses()
    regs = Inkfish.Users.list_regs_for_user(conn.assigns[:current_user])
    reqs = Inkfish.JoinReqs.list_for_user(conn.assigns[:current_user])
    render(conn, "index.html", courses: courses, regs: regs, reqs: reqs)
  end

  def show(conn, %{"id" => _id}) do
    current_reg =
      conn.assigns[:current_reg]
      |> Users.preload_reg_teams!()

    course =
      conn.assigns[:course]
      |> Courses.add_solo_team(current_reg)
      |> Courses.reload_course_for_student_view!(current_reg)

    teams = Courses.get_teams_for_student!(course, current_reg)
    totals = bucket_totals(course.buckets)
    render(conn, "show.html", course: course, teams: teams, totals: totals)
  end

  def bucket_totals(buckets) do
    for bucket <- buckets do
      base = {Decimal.new("0.0"), Decimal.new("0.0")}

      {s, p} =
        Enum.reduce(bucket.assignments, base, fn as, {s, p} ->
          zero_sub = Subs.make_zero_sub(as)
          sub = Enum.find(as.subs, zero_sub, & &1.active)
          score = sub.score || Decimal.new("0.0")
          weight = fix_weight(as.weight)
          points = Assignment.assignment_total_points(as)
          frac = Decimal.div(Decimal.mult(weight, score), fix_weight(points))
          # IO.inspect({as.id, sub.id, frac, points})
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

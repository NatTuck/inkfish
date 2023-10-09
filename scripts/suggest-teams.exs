defmodule SuggestTeams do
  alias Inkfish.Users
  alias Inkfish.Assignments
  alias Inkfish.Courses
  alias Inkfish.Assignments
  alias Inkfish.Teams
  alias InkfishWeb.ViewHelpers

  def main(ts_id) do
    ts = Teams.get_teamset!(ts_id)
    course = ts.course
    students = list_students(course)
    teams = list_teams(course)

    lab_ids = lab02(students) |> Enum.shuffle()
    IO.inspect {:ids_len, length(lab_ids)}
    
    counts = pair_counts(lab_ids, teams)

    combos = partners_search(lab_ids, counts)

    IO.inspect {:combos_len, length(combos)}
    IO.inspect {:combos, combos}

    tops = combos
    |> Enum.map(&({score_teams(&1, counts), &1}))
    |> Enum.sort_by(fn {score, _} -> score end)
    |> Enum.take(3)

    IO.puts("\n== Top 3 ==")
    Enum.each tops, fn {score, teams} ->
      IO.puts "Score: #{score}"
      Enum.each teams, fn team ->
        names = Enum.map(team, &(display(&1, students)))
        IO.inspect names
      end
    end
  end

  def partners_search(xs, _counts) when length(xs) <= 3 do
    [[Enum.sort(xs)]]
  end
  def partners_search(xs, counts) when length(xs) <= 6 do
    for aa <- xs, bb <- xs, aa < bb, rest <- partners_search(xs -- [aa, bb], counts) do
      [[aa, bb] | rest]
    end
  end
  def partners_search(xs, counts) do
    t1s = for aa <- xs, bb <- xs, aa < bb do
      [aa, bb]
    end
    t1 = hd(Enum.sort_by(t1s, &score_team(&1, counts)))
    Enum.map partners_search(xs -- t1, counts), fn rest ->
      [t1 | rest]
    end
  end

  def score_teams(teams, counts) do
    Enum.map(teams, &score_team(&1, counts))
    |> Enum.sum()
  end

  def score_team(team, counts) do
    Inkfish.Combos.uniq_pairs_from(team)
    |> Enum.map(fn team ->
      Map.get(counts, team, 0)
    end)
    |> Enum.sum()
  end

  # https://elixirforum.com/t/most-elegant-way-to-generate-all-permutations/2706
  def pair_counts(users, teams) do
    teams_by_user = users
    |> Enum.map(fn uu ->
      teams = Enum.filter teams, fn team ->
        Enum.any?(team, &(&1 == uu))
      end
      {uu, teams}
    end)
    |> Enum.into(%{})

    for u0 <- users, u1 <- users, u0 < u1 do
      ts = Map.get(teams_by_user, u0)
      nn = Enum.count ts, fn team ->
        Enum.any?(team, &(&1 == u1))
      end

      {{u0, u1}, nn}
    end
    |> Enum.into(%{})
  end

  def list_teams(course) do
    Teams.list_teamsets(course)
    |> Enum.map(fn ts ->
      teams = Teams.list_teams(ts.id)
      |> Enum.map(fn team ->
        Teams.get_team!(team.id)
      end)

      %Teams.Teamset{ts | teams: teams}
    end)
    |> Enum.flat_map(&(&1.teams))
    |> Enum.map(&team_users(&1))
  end

  def team_users(team) do
    Enum.map team.regs, fn reg ->
      reg.user_id
    end
  end

  def list_students(course) do
    course
    |> Users.list_regs_for_course()
    |> Enum.filter(&(&1.is_student))
    |> Enum.map(&(&1.user))
  end

  def display(%Users.User{} = user) do
    name = ViewHelpers.user_display_name(user)
    "#{name} (#{user.id})"
  end

  def display(id, students) do
    Enum.find(students, &(&1.id == id))
    |> display()
  end

  def lab01_set() do
    # DS Fall 2013 lab01 students
    MapSet.new([8, 10, 11, 27, 9, 14, 13])
  end

  def lab01(students) do
    students
    |> Enum.map(&(&1.id))
    |> Enum.filter(&(MapSet.member?(lab01_set(), &1)))
  end

  def lab02(students) do
    students
    |> Enum.map(&(&1.id))
    |> Enum.filter(&(!MapSet.member?(lab01_set(), &1)))
  end
end

argv = System.argv()

[ts_id] = argv
{ts_id, _} = Integer.parse(ts_id)

SuggestTeams.main(ts_id)

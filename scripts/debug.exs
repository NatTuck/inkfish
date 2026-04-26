defmodule DebugSanityCheck do
  alias Inkfish.Repo
  alias Inkfish.Subs.Sub
  alias Inkfish.Subs.ActiveSub
  alias Inkfish.Assignments.Assignment
  alias Inkfish.Courses.Course
  alias Inkfish.Users.Reg
  import Ecto.Query

  def run do
    IO.puts("=" |> String.duplicate(80))
    IO.puts("ACTIVE SUB SANITY CHECK REPORT")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("")

    # Get all active_sub records with full context
    active_subs = get_all_active_subs_with_context()

    IO.puts("Total active_subs checked: #{length(active_subs)}")
    IO.puts("")

    # For each active_sub, verify it's the best choice
    discrepancies =
      Enum.flat_map(active_subs, fn as ->
        reg = as.reg
        asg = as.assignment
        sub = as.sub

        # Get all candidate subs for this reg/assignment
        candidates = get_candidate_subs(reg.id, asg.id)

        # Find the best sub (highest score, or most recent if tied)
        best = find_best_sub(candidates)

        # If active sub is not the best, report it
        if best && best.id != sub.id do
          [%{
            course: asg.bucket.course.name,
            assignment: asg.name,
            user: "#{reg.user.given_name} #{reg.user.surname}",
            active_sub: sub,
            active_sub_score: sub.score,
            active_sub_inserted: sub.inserted_at,
            best_sub_id: best.id,
            best_sub_score: best.score,
            best_sub_inserted: best.inserted_at,
            reason: why_not_best(sub, best, candidates)
          }]
        else
          []
        end
      end)

    IO.puts("Discrepancies found: #{length(discrepancies)}")
    IO.puts("")

    if length(discrepancies) > 0 do
      Enum.each(discrepancies, &print_discrepancy/1)
    else
      IO.puts("✓ All active subs are optimal!")
    end

    IO.puts("")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("SANITY CHECK COMPLETE")
    IO.puts("=" |> String.duplicate(80))
  end

  defp get_all_active_subs_with_context do
    Repo.all(
      from as in ActiveSub,
        join: reg in assoc(as, :reg),
        join: user in assoc(reg, :user),
        join: sub in assoc(as, :sub),
        join: asg in assoc(as, :assignment),
        join: bucket in assoc(asg, :bucket),
        join: course in assoc(bucket, :course),
        preload: [
          reg: {reg, user: user},
          sub: sub,
          assignment: {asg, bucket: {bucket, course: course}}
        ]
    )
  end

  defp get_candidate_subs(reg_id, asg_id) do
    # All subs for this reg/assignment via team membership
    Repo.all(
      from s in Sub,
        join: t in assoc(s, :team),
        join: tm in assoc(t, :team_members),
        where: tm.reg_id == ^reg_id,
        where: s.assignment_id == ^asg_id,
        preload: [team: :team_members]
    )
  end

  defp find_best_sub(subs) do
    # Prefer: has score > no score, then higher score, then most recent
    subs
    |> Enum.sort_by(fn s ->
      has_score = if s.score, do: 1, else: 0
      score_val = s.score || Decimal.new("0")
      {has_score, score_val, s.inserted_at}
    end, :desc)
    |> List.first()
  end

  defp get_team_members_for_sub(sub) do
    sub = Repo.preload(sub, team: [team_members: :reg])

    sub.team.team_members
    |> Enum.map(fn tm ->
      reg = tm.reg
      user = reg.user
      "#{user.given_name} #{user.surname}"
    end)
    |> Enum.join(", ")
  end

  defp why_not_best(active, best, _candidates) do
    cond do
      active.score == nil && best.score != nil ->
        "Active sub has no score but best sub has score #{best.score}"

      active.score != nil && best.score != nil &&
          Decimal.compare(active.score, best.score) == :lt ->
        "Active sub score (#{active.score}) < best score (#{best.score})"

      DateTime.compare(active.inserted_at, best.inserted_at) == :lt ->
        "Active sub is older than best sub"

      true ->
        "Unknown reason"
    end
  end

  defp print_discrepancy(d) do
    IO.puts("\n--- DISCREPANCY ---")
    IO.puts("Course: #{d.course}")
    IO.puts("Assignment: #{d.assignment}")
    IO.puts("User: #{d.user}")

    IO.puts(
      "Active Sub: id=#{d.active_sub.id}, score=#{d.active_sub_score || "none"}, inserted=#{d.active_sub_inserted}"
    )

    IO.puts(
      "Best Sub: id=#{d.best_sub_id}, score=#{d.best_sub_score || "none"}, inserted=#{d.best_sub_inserted}"
    )

    IO.puts("Why: #{d.reason}")
  end
end

DebugSanityCheck.run()

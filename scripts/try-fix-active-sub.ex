#!/usr/bin/env elixir
# scripts/try-fix-active-sub.ex

# Run with: mix run scripts/try-fix-active-sub.ex
# Tests fix logic on specific orphaned cases: team 651, sub 2510

alias Inkfish.Repo
alias Inkfish.Subs
alias Inkfish.Subs.Sub

import Ecto.Query

IO.puts("=== Try Fix Active Sub Script ===\n")

# Test Case 1: Sub 2510 (has score=50.0, ignore_late=true, active=false)
IO.puts("--- Test Case 1: Sub 2510 (has score + ignore_late) ---")
sub2510 = Repo.get(Sub, 2510)

if sub2510 do
  IO.puts("Sub 2510 state:")
  IO.puts("  active: #{sub2510.active}")
  IO.puts("  score: #{if sub2510.score, do: Decimal.to_string(sub2510.score), else: "nil"}")
  IO.puts("  ignore_late_penalty: #{sub2510.ignore_late_penalty}")
  IO.puts("  assignment_id: #{sub2510.assignment_id}")
  IO.puts("  team_id: #{sub2510.team_id}")

  # Check if there's currently an active sub for this team/asg
  current_active = Subs.active_sub_for_team(sub2510.assignment_id, sub2510.team_id)
  IO.puts("  Currently active sub: #{if current_active, do: "sub ##{current_active.id}", else: "nil"}")

  IO.puts("\nRunning set_one_sub_active(sub2510)...")

  case Subs.set_one_sub_active(sub2510) do
    {:ok, active_sub} ->
      IO.puts("SUCCESS: Activated sub ##{active_sub.id}")

    {:error, reason} ->
      IO.puts("FAILED: #{inspect(reason)}")
  end

  # Verify
  new_active = Subs.active_sub_for_team(sub2510.assignment_id, sub2510.team_id)
  IO.puts("\nAfter fix - active sub: #{if new_active, do: "sub ##{new_active.id}", else: "STILL NONE"}")

  # Reload sub to see if it changed
  sub2510_reloaded = Repo.get(Sub, 2510)
  IO.puts("Sub 2510 active now: #{sub2510_reloaded.active}")
else
  IO.puts("ERROR: Sub 2510 not found")
end

IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

# Test Case 2: Team 651 (has 3 subs, all inactive)
IO.puts("--- Test Case 2: Team 651 (3 orphaned subs) ---")

subs_team_651 =
  Repo.all(
    from(s in Sub,
      where: s.team_id == 651,
      order_by: [desc: s.inserted_at]
    )
  )

IO.puts("Found #{length(subs_team_651)} subs for team 651:")

for sub <- subs_team_651 do
  score_str = if sub.score, do: Decimal.to_string(sub.score), else: "nil"
  IO.puts("  Sub #{sub.id}: active=#{sub.active}, score=#{score_str}, " <>
            "ignore_late=#{sub.ignore_late_penalty}, asg=#{sub.assignment_id}")
end

if length(subs_team_651) > 0 do
  most_recent = List.first(subs_team_651)
  asg_id = most_recent.assignment_id

  IO.puts("\nMost recent sub: ##{most_recent.id}")

  # Check current active state
  current_active = Subs.active_sub_for_team(asg_id, 651)
  IO.puts("Currently active: #{if current_active, do: "sub ##{current_active.id}", else: "nil"}")

  IO.puts("\nRunning set_one_sub_active on most recent sub...")

  case Subs.set_one_sub_active(most_recent) do
    {:ok, active_sub} ->
      IO.puts("SUCCESS: Activated sub ##{active_sub.id}")

    {:error, reason} ->
      IO.puts("FAILED: #{inspect(reason)}")
  end

  # Verify
  new_active = Subs.active_sub_for_team(asg_id, 651)
  IO.puts("\nAfter fix - active sub: #{if new_active, do: "sub ##{new_active.id}", else: "STILL NONE"}")

  # Show all subs after fix
  subs_after =
    Repo.all(
      from(s in Sub,
        where: s.team_id == 651,
        order_by: [desc: s.inserted_at]
      )
    )

  IO.puts("\nSubs after fix:")
  for sub <- subs_after do
    IO.puts("  Sub #{sub.id}: active=#{sub.active}")
  end
end

IO.puts("\n=== Done ===")

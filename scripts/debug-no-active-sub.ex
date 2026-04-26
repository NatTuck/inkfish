#!/usr/bin/env elixir
# scripts/debug-no-active-sub.ex

# Run with: mix run scripts/debug-no-active-sub.ex
# Analyzes ALL orphaned groups and shows patterns

alias Inkfish.Repo
alias Inkfish.Subs
alias Inkfish.Subs.Sub
alias Inkfish.Subs.Repair

import Ecto.Query

IO.puts("=== Debug No Active Sub Script ===\n")

# Find all orphaned groups
orphaned_groups = Repair.find_orphaned_sub_groups()

total_groups = length(orphaned_groups)
IO.puts("Found #{total_groups} orphaned groups\n")

if orphaned_groups == [] do
  IO.puts("No orphaned groups found. Exiting.")
  exit(:normal)
end

# Analyze each orphaned group
for {orphaned, idx} <- Enum.with_index(orphaned_groups, 1) do
  asg_id = orphaned.assignment_id
  team_id = orphaned.team_id

  IO.puts("--- Group #{idx}/#{total_groups} ---")
  IO.puts("Assignment ID: #{asg_id}, Team ID: #{team_id}")

  # Get all subs for this group
  subs =
    Repo.all(
      from(s in Sub,
        where: s.assignment_id == ^asg_id and s.team_id == ^team_id,
        order_by: [desc: s.inserted_at]
      )
    )

  IO.puts("  Total subs: #{length(subs)}")

  for sub <- subs do
    score_str = if sub.score, do: Decimal.to_string(sub.score), else: "nil"
    grader_str = if sub.grader_id, do: "grader=#{sub.grader_id}", else: "no_grader"

    IO.puts(
      "    Sub #{sub.id}: active=#{sub.active}, score=#{score_str}, " <>
        "ignore_late=#{sub.ignore_late_penalty}, #{grader_str}, inserted_at=#{sub.inserted_at}"
    )
  end

  # Check for previous active sub
  prev = Subs.active_sub_for_team(asg_id, team_id)

  if prev do
    IO.puts("  ERROR: Found active sub ##{prev.id} (should not happen for orphaned group!)")
  else
    IO.puts("  No active sub (confirmed orphaned)")
  end

  IO.puts("")
end

IO.puts("\n=== Summary ===")
IO.puts("Total orphaned groups: #{total_groups}")

# Group by assignment to see patterns
by_assignment = Enum.group_by(orphaned_groups, & &1.assignment_id)

IO.puts("\nBy Assignment:")

for {asg_id, groups} <- by_assignment do
  assignment = Repo.get(Inkfish.Assignments.Assignment, asg_id)
  name = if assignment, do: assignment.name, else: "Unknown"
  IO.puts("  Assignment #{asg_id} (#{name}): #{length(groups)} orphaned teams")
end

IO.puts("\nDone.")

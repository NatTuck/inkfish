#!/usr/bin/env elixir
# scripts/activate-one-sub.exs
# Run with: mix run scripts/activate-one-sub.exs SUB_ID
#
# Duplicates the set_one_sub_active logic with detailed logging
# to diagnose activation failures.

alias Inkfish.Repo
alias Inkfish.Subs
alias Inkfish.Subs.Sub
alias Inkfish.Teams
alias Inkfish.Teams.Team

import Ecto.Query

# Get sub_id from command line
sub_id =
  case System.argv() do
    [id_str | _] -> String.to_integer(id_str)
    [] ->
      IO.puts("Usage: mix run scripts/activate-one-sub.exs SUB_ID")
      exit(:normal)
  end

IO.puts("=== Activate One Sub Debug Script ===")
IO.puts("Target Sub ID: #{sub_id}\n")

# Fetch the sub
sub = Repo.get(Sub, sub_id)

unless sub do
  IO.puts("ERROR: Sub #{sub_id} not found")
  exit(:normal)
end

IO.puts("Sub Details:")
IO.puts("  ID: #{sub.id}")
IO.puts("  Assignment ID: #{sub.assignment_id}")
IO.puts("  Team ID: #{sub.team_id}")
IO.puts("  Active: #{sub.active}")
IO.puts("  Score: #{if sub.score, do: Decimal.to_string(sub.score), else: "nil"}")
IO.puts("  Ignore Late Penalty: #{sub.ignore_late_penalty}")
IO.puts("")

asg_id = sub.assignment_id
team_id = sub.team_id

# Step 1: Check for existing active sub
IO.puts("Step 1: Checking for existing active sub...")
prev = Subs.active_sub_for_team(asg_id, team_id)

if prev do
  IO.puts("  Found active sub ##{prev.id}")
  IO.puts("    Score: #{if prev.score, do: Decimal.to_string(prev.score), else: "nil"}")
  IO.puts("    Ignore Late: #{prev.ignore_late_penalty}")
else
  IO.puts("  No active sub found")
end

# Step 2: Determine target
target =
  if prev && (prev.score || prev.ignore_late_penalty) do
    IO.puts("\nStep 2: Strategy = KEEP existing active sub (has score or ignore_late)")
    prev
  else
    IO.puts("\nStep 2: Strategy = ACTIVATE new sub")
    sub
  end

IO.puts("  Target sub: ##{target.id}")

# Step 3: Get team and member info
IO.puts("\nStep 3: Fetching team #{team_id}...")
team = Teams.get_team(team_id)

unless team do
  IO.puts("  ERROR: Team not found!")
  exit(:normal)
end

member_ids = Enum.map(team.team_members, & &1.reg_id)
IO.puts("  Team members: #{length(member_ids)} (reg_ids: #{inspect(member_ids)})")

# Step 4: Find all teams sharing members
IO.puts("\nStep 4: Finding all teams sharing members...")
teams =
  Repo.all(
    from(tt in Team,
      left_join: members in assoc(tt, :team_members),
      where: members.reg_id in ^member_ids,
      preload: [team_members: {members, reg: :user}]
    )
  )

team_ids = Enum.map(teams, & &1.id)
IO.puts("  Found #{length(teams)} teams: #{inspect(team_ids)}")

for t <- teams do
  member_names =
    t.team_members
    |> Enum.map(fn tm -> "#{tm.reg.user.given_name} #{tm.reg.user.surname}" end)
    |> Enum.join(", ")
  IO.puts("    Team #{t.id}: #{member_names}")
end

# Step 5: Show subs that will be deactivated
IO.puts("\nStep 5: Subs that will be deactivated:")
subs_to_deactivate =
  Repo.all(
    from(s in Sub,
      where: s.assignment_id == ^asg_id,
      where: s.team_id in ^team_ids,
      where: s.active == true
    )
  )

if subs_to_deactivate == [] do
  IO.puts("  (none currently active)")
else
  for s <- subs_to_deactivate do
    IO.puts("  Sub ##{s.id} (team #{s.team_id}) - will be deactivated")
  end
end

# Step 6: Execute activation
IO.puts("\nStep 6: Executing activation...")
IO.puts("  Running: set_sub_active(sub ##{target.id})")

result = Subs.set_sub_active(target)

case result do
  {:ok, activated_sub} ->
    IO.puts("  SUCCESS: Activated sub ##{activated_sub.id}")

  {:error, changeset} ->
    IO.puts("  FAILED: #{inspect(changeset.errors)}")
end

# Step 7: Verify
IO.puts("\nStep 7: Verification...")
verified = Subs.active_sub_for_team(asg_id, team_id)

if verified do
  IO.puts("  ✓ Active sub confirmed: ##{verified.id}")
else
  IO.puts("  ✗ NO ACTIVE SUB FOUND!")
end

# Step 8: Show all subs for this assignment/team scope
IO.puts("\nStep 8: All subs for assignment #{asg_id} in scope:")
all_subs =
  Repo.all(
    from(s in Sub,
      where: s.assignment_id == ^asg_id,
      where: s.team_id in ^team_ids,
      order_by: [desc: s.inserted_at]
    )
  )

for s <- all_subs do
  marker = if s.active, do: " [ACTIVE]", else: ""
  IO.puts("  Sub ##{s.id} (team #{s.team_id})#{marker}")
end

IO.puts("\n=== Done ===")

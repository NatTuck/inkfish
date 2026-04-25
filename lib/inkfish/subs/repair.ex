defmodule Inkfish.Subs.Repair do
  @moduledoc """
  Repair functions for subs data integrity issues.
  """

  alias Inkfish.Repo
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub

  import Ecto.Query

  @doc """
  Finds subs in teams/assignments that have subs but no active sub,
  and activates the most recent one according to the standard logic
  (preferring subs with scores or ignore_late_penalty set).

  Returns the count of orphaned groups that were fixed.
  """
  def fix_active_subs do
    orphaned_groups = find_orphaned_sub_groups()

    Enum.each(orphaned_groups, fn %{assignment_id: asg_id, team_id: team_id} ->
      # Get most recent sub for this team/assignment
      sub =
        from(s in Sub,
          where: s.assignment_id == ^asg_id and s.team_id == ^team_id,
          order_by: [desc: s.inserted_at],
          limit: 1
        )
        |> Repo.one!()

      # Use set_one_sub_active to follow standard logic
      # (keeps existing active sub if graded, otherwise activates most recent)
      # This now guarantees that if subs exist, exactly one will be active
      Subs.set_one_sub_active(sub)
    end)

    length(orphaned_groups)
  end

  @doc """
  Returns a list of %{assignment_id: id, team_id: id} maps
  for groups that have subs but no active sub.
  """
  def find_orphaned_sub_groups do
    from(s in Sub,
      group_by: [s.assignment_id, s.team_id],
      having: count(s.id) > 0,
      having: fragment("count(*) FILTER (WHERE active = true) = 0"),
      select: %{assignment_id: s.assignment_id, team_id: s.team_id}
    )
    |> Repo.all()
  end

  @doc """
  Returns the count of orphaned sub groups (for diagnostics).
  """
  def count_orphaned_sub_groups do
    find_orphaned_sub_groups() |> length()
  end
end

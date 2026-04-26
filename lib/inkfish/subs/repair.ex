defmodule Inkfish.Subs.Repair do
  @moduledoc """
  Repair functions for subs data integrity issues.
  """

  alias Inkfish.Repo
  alias Inkfish.Subs.Sub
  alias Inkfish.Subs.ActiveSub

  import Ecto.Query

  @doc """
  Finds orphaned sub groups with detailed information including
  course name, assignment details, and reg info.

  Returns a list of maps with:
  - :assignment_id, :reg_id
  - :course_name
  - :assignment_name
  - :user_name
  """
  def find_orphaned_sub_groups_detailed do
    orphaned = find_orphaned_sub_groups()

    Enum.map(orphaned, fn %{assignment_id: asg_id, reg_id: reg_id} ->
      get_reg_details(asg_id, reg_id)
    end)
  end

  defp get_reg_details(asg_id, reg_id) do
    # Get assignment with course info
    assignment =
      Repo.one(
        from(a in Inkfish.Assignments.Assignment,
          where: a.id == ^asg_id,
          join: b in assoc(a, :bucket),
          join: c in assoc(b, :course),
          select: %{id: a.id, name: a.name, course_name: c.name}
        )
      )

    course_name = if assignment, do: assignment.course_name, else: "Unknown"
    assignment_name = if assignment, do: assignment.name, else: "Unknown"

    # Get reg with user name
    reg =
      Repo.one(
        from(r in Inkfish.Users.Reg,
          where: r.id == ^reg_id,
          join: u in assoc(r, :user),
          select: %{
            id: r.id,
            user_name: fragment("? || ' ' || ?", u.given_name, u.surname)
          }
        )
      )

    user_name = if reg, do: reg.user_name, else: "Unknown"

    %{
      assignment_id: asg_id,
      reg_id: reg_id,
      course_name: course_name,
      assignment_name: assignment_name,
      user_name: user_name
    }
  end

  @doc """
  Finds regs that have subs for an assignment but no active sub,
  and activates the most recent one according to the standard logic
  (preferring subs with scores or ignore_late_penalty set).

  Returns a map with:
  - :fixed_count - number of successfully fixed regs
  - :failed_count - number of failed fixes
  - :results - list of %{status: :ok | :error, reg: reg_id, assignment: asg_id, message: string}
  """
  def fix_active_subs do
    orphaned_pairs = find_orphaned_sub_groups()

    results =
      Enum.map(orphaned_pairs, fn %{assignment_id: asg_id, reg_id: reg_id} ->
        # Get all subs for this reg/assignment (via team membership)
        subs =
          Repo.all(
            from(s in Sub,
              join: t in assoc(s, :team),
              join: tm in assoc(t, :team_members),
              where: tm.reg_id == ^reg_id,
              where: s.assignment_id == ^asg_id,
              order_by: [
                desc:
                  fragment(
                    "CASE WHEN ? IS NOT NULL OR ? THEN 1 ELSE 0 END",
                    s.score,
                    s.ignore_late_penalty
                  ),
                desc: s.inserted_at
              ]
            )
          )

        case subs do
          [] ->
            %{
              status: :error,
              reg: reg_id,
              assignment: asg_id,
              message: "No subs found"
            }

          [best_sub | _] ->
            # Use set_sub_active which properly handles team member active_sub records
            case Inkfish.Subs.set_sub_active(best_sub) do
              {:ok, _} ->
                %{
                  status: :ok,
                  reg: reg_id,
                  assignment: asg_id,
                  message: "Activated sub ##{best_sub.id}"
                }

              {:error, reason} ->
                %{
                  status: :error,
                  reg: reg_id,
                  assignment: asg_id,
                  message: "Failed to activate: #{inspect(reason)}"
                }
            end
        end
      end)

    fixed_count = Enum.count(results, &(&1.status == :ok))
    failed_count = Enum.count(results, &(&1.status == :error))

    %{
      total: length(orphaned_pairs),
      fixed_count: fixed_count,
      failed_count: failed_count,
      results: results
    }
  end

  @doc """
  Returns a list of %{assignment_id: id, reg_id: id} maps
  for regs that have subs for an assignment but no active_sub record.
  """
  def find_orphaned_sub_groups do
    # Find reg/assignment pairs that have subs but no active_sub
    from(s in Sub,
      join: t in assoc(s, :team),
      join: tm in assoc(t, :team_members),
      join: r in assoc(tm, :reg),
      left_join: as in ActiveSub,
      on: as.reg_id == r.id and as.assignment_id == s.assignment_id,
      where: is_nil(as.id),
      distinct: [s.assignment_id, r.id],
      select: %{assignment_id: s.assignment_id, reg_id: r.id}
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

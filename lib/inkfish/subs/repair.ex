defmodule Inkfish.Subs.Repair do
  @moduledoc """
  Repair functions for subs data integrity issues.
  """

  alias Inkfish.Repo
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Teams

  import Ecto.Query

  @doc """
  Finds orphaned sub groups with detailed information including
  course name, assignment details, and team member names.

  Returns a list of maps with:
  - :assignment_id, :team_id
  - :course_name
  - :assignment_name
  - :team_member_names (comma-separated string)
  """
  def find_orphaned_sub_groups_detailed do
    orphaned = find_orphaned_sub_groups()

    Enum.map(orphaned, fn %{assignment_id: asg_id, team_id: team_id} ->
      get_group_details(asg_id, team_id)
    end)
  end

  defp get_group_details(asg_id, team_id) do
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

    # Get team with member names
    team = Teams.get_team(team_id)

    member_names =
      if team do
        team.team_members
        |> Enum.map(fn tm ->
          user = tm.reg.user
          "#{user.given_name} #{user.surname}"
        end)
        |> Enum.join(", ")
      else
        "Team not found"
      end

    %{
      assignment_id: asg_id,
      team_id: team_id,
      course_name: course_name,
      assignment_name: assignment_name,
      team_member_names: member_names
    }
  end

  @doc """
  Finds subs in teams/assignments that have subs but no active sub,
  and activates the most recent one according to the standard logic
  (preferring subs with scores or ignore_late_penalty set).

  Returns a map with:
  - :fixed_count - number of successfully fixed groups
  - :failed_count - number of failed fixes
  - :results - list of %{status: :ok | :error, group: details, message: string}
  """
  def fix_active_subs do
    orphaned_groups = find_orphaned_sub_groups()

    results =
      Enum.map(orphaned_groups, fn %{assignment_id: asg_id, team_id: team_id} ->
        group_details = get_group_details(asg_id, team_id)

        # Get most recent sub for this team/assignment
        sub =
          Repo.one(
            from(s in Sub,
              where: s.assignment_id == ^asg_id and s.team_id == ^team_id,
              order_by: [desc: s.inserted_at],
              limit: 1
            )
          )

        case sub do
          nil ->
            %{status: :error, group: group_details, message: "No sub found"}

          sub ->
            case Subs.set_one_sub_active(sub) do
              {:ok, active_sub} ->
                %{
                  status: :ok,
                  group: group_details,
                  message: "Activated sub ##{active_sub.id}"
                }

              {:error, reason} ->
                %{
                  status: :error,
                  group: group_details,
                  message: "Failed: #{inspect(reason)}"
                }
            end
        end
      end)

    fixed_count = Enum.count(results, &(&1.status == :ok))
    failed_count = Enum.count(results, &(&1.status == :error))

    %{
      total: length(orphaned_groups),
      fixed_count: fixed_count,
      failed_count: failed_count,
      results: results
    }
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

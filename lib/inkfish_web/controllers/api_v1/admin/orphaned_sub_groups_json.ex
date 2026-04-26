defmodule InkfishWeb.ApiV1.Admin.OrphanedSubGroupsJSON do
  use InkfishWeb, :json

  @doc """
  Renders a list of orphaned sub groups.
  """
  def index(%{orphaned_groups: orphaned_groups}) do
    %{
      data: %{
        orphaned_count: length(orphaned_groups),
        orphaned_groups: Enum.map(orphaned_groups, &group_data/1)
      }
    }
  end

  @doc """
  Renders fix results and remaining orphaned groups after fix.
  """
  def fix(%{fix_results: fix_results, orphaned_groups: orphaned_groups}) do
    %{
      data: %{
        fix_results: %{
          total: fix_results.total,
          fixed_count: fix_results.fixed_count,
          failed_count: fix_results.failed_count,
          results:
            Enum.map(fix_results.results, fn result ->
              %{
                status: result.status,
                group: group_data(result.group),
                message: result.message
              }
            end)
        },
        orphaned_groups_after_fix: %{
          orphaned_count: length(orphaned_groups),
          orphaned_groups: Enum.map(orphaned_groups, &group_data/1)
        }
      }
    }
  end

  defp group_data(group) do
    %{
      assignment_id: group.assignment_id,
      team_id: group.team_id,
      course_name: group.course_name,
      assignment_name: group.assignment_name,
      team_member_names: group.team_member_names
    }
  end
end

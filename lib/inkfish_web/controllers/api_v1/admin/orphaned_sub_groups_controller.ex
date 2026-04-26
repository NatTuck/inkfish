defmodule InkfishWeb.ApiV1.Admin.OrphanedSubGroupsController do
  use InkfishWeb, :controller

  alias Inkfish.Subs.Repair

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser
  plug InkfishWeb.Plugs.RequireApiAdmin

  def index(conn, _params) do
    orphaned_groups = Repair.find_orphaned_sub_groups_detailed()

    conn
    |> put_view(InkfishWeb.ApiV1.Admin.OrphanedSubGroupsJSON)
    |> render(:index, orphaned_groups: orphaned_groups)
  end

  def fix(conn, _params) do
    fix_results = Repair.fix_active_subs()
    orphaned_groups = Repair.find_orphaned_sub_groups_detailed()

    conn
    |> put_view(InkfishWeb.ApiV1.Admin.OrphanedSubGroupsJSON)
    |> render(:fix, fix_results: fix_results, orphaned_groups: orphaned_groups)
  end
end

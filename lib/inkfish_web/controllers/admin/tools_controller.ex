defmodule InkfishWeb.Admin.ToolsController do
  use InkfishWeb, :controller

  alias Inkfish.Subs.Repair

  plug InkfishWeb.Plugs.Breadcrumb, {"Admin Tools", :admin_tools, :index}

  def index(conn, _params) do
    orphaned_groups = Repair.find_orphaned_sub_groups_detailed()
    orphaned_count = length(orphaned_groups)

    render(conn, "index.html",
      orphaned_count: orphaned_count,
      orphaned_groups: orphaned_groups,
      fix_results: nil
    )
  end

  def fix_active_subs(conn, _params) do
    results = Repair.fix_active_subs()
    orphaned_groups = Repair.find_orphaned_sub_groups_detailed()

    flash_message =
      "Fixed #{results.fixed_count}/#{results.total} orphaned submission groups. " <>
        "#{results.failed_count} failed."

    conn
    |> put_flash(:info, flash_message)
    |> render("index.html",
      orphaned_count: length(orphaned_groups),
      orphaned_groups: orphaned_groups,
      fix_results: results
    )
  end
end

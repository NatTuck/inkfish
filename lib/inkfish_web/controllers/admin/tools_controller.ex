defmodule InkfishWeb.Admin.ToolsController do
  use InkfishWeb, :controller

  alias Inkfish.Subs.Repair

  plug InkfishWeb.Plugs.Breadcrumb, {"Admin Tools", :admin_tools, :index}

  def index(conn, _params) do
    orphaned_count = Repair.count_orphaned_sub_groups()
    render(conn, "index.html", orphaned_count: orphaned_count)
  end

  def fix_active_subs(conn, _params) do
    fixed_count = Repair.fix_active_subs()

    conn
    |> put_flash(:info, "Fixed #{fixed_count} orphaned submission groups.")
    |> redirect(to: ~p"/admin/tools")
  end
end

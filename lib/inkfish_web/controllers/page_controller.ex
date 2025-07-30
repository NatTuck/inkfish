defmodule InkfishWeb.PageController do
  use InkfishWeb, :controller

  def index(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/dashboard")
    else
      conn
      |> assign(:page_title, "Welcome")
      |> render(:index)
    end
  end

  def dashboard(conn, _params) do
    if user = conn.assigns[:current_user] do
      regs =
        Enum.filter(Inkfish.Users.list_regs_for_user(user), fn reg ->
          !reg.course.archived
        end)

      dues =
        Enum.reduce(regs, %{}, fn reg, acc ->
          next = Inkfish.Users.next_due(reg)
          Map.put(acc, reg.course_id, next)
        end)

      render(conn, :dashboard, regs: regs, dues: dues)
    else
      redirect(conn, to: ~p"/")
    end
  end
end

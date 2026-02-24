defmodule InkfishWeb.Plugs.RequireApiStaff do
  use InkfishWeb, :controller

  alias Inkfish.Users

  def init(args), do: args

  def call(conn, _args \\ []) do
    user = conn.assigns[:current_user]

    regs = Users.list_regs_for_user(user.id)

    if regs == [] do
      assign(conn, :current_staff_regs, [])
    else
      staff_regs = Enum.filter(regs, fn reg -> reg.is_staff or reg.is_prof end)

      if staff_regs == [] && !user.is_admin do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, ~s({"error": "Access denied"}))
        |> halt
      else
        assign(conn, :current_staff_regs, staff_regs)
      end
    end
  end
end

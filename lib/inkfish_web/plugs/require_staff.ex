defmodule InkfishWeb.Plugs.RequireStaff do
  use InkfishWeb, :controller

  alias Inkfish.Users

  def init(args), do: args

  def call(conn, _args) do
    user = conn.assigns[:current_user]

    if is_nil(user) do
      respond_with_error(conn, 403, "Please log in.")
    else
      regs = Users.list_regs_for_user(user.id)
      staff_regs = Enum.filter(regs, fn reg -> reg.is_staff or reg.is_prof end)

      if staff_regs == [] && !user.is_admin do
        respond_with_error(conn, 403, "Access denied.")
      else
        assign(conn, :current_staff_regs, staff_regs)
      end
    end
  end
end

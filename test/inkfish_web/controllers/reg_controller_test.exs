defmodule InkfishWeb.RegControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  def create_reg(_) do
    user = insert(:user)
    reg = insert(:reg, user: user, is_student: true)
    {:ok, reg: reg, user: user}
  end

  describe "show reg" do
    setup [:create_reg]

    test "shows reg", %{conn: conn, reg: reg, user: user} do
      conn =
        conn
        |> login(user.email)
        |> get(~p"/regs/#{reg.id}")

      assert html_response(conn, 200) =~ "Show Reg"
    end
  end
end

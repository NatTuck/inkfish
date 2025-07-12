defmodule InkfishWeb.JoinReqControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  def fixture(:join_req) do
    insert(:join_req)
  end

  defp create_stock_course(_) do
    %{course: course} = stock_course()
    {:ok, course: course}
  end

  describe "new join_req" do
    setup [:create_stock_course]

    test "renders form", %{conn: conn, course: course} do
      conn =
        conn
        |> login("erin@example.com")
        |> get(~p"/courses/#{course}/join_reqs/new")

      assert html_response(conn, 200) =~ "New Joinreq"
    end
  end

  describe "create join_req" do
    setup [:create_stock_course]

    test "redirects to root when data is valid", %{conn: conn, course: course} do
      params = params_for(:join_req)

      conn =
        conn
        |> login("erin@example.com")
        |> post(~p"/courses/#{course}/join_reqs",
          join_req: params
        )

      assert redirected_to(conn) == ~p"/courses"
    end
  end
end

defmodule InkfishWeb.AgJobControllerTest do
  use InkfishWeb.ConnCase

  describe "index" do
    test "lists all ag_jobs", %{conn: conn} do
      conn =
        conn
        |> login("erin@example.com")
        |> get(~p"/ag_jobs")

      assert html_response(conn, 200) =~ "Autograding Jobs"
    end
  end
end

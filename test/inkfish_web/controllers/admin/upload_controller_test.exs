defmodule InkfishWeb.Admin.UploadControllerTest do
  use InkfishWeb.ConnCase

  describe "index" do
    test "lists all uploads", %{conn: conn} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/admin/uploads")

      assert html_response(conn, 200) =~ "Listing Uploads"
    end
  end
end

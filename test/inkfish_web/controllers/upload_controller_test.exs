defmodule InkfishWeb.UploadControllerTest do
  use InkfishWeb.ConnCase

  describe "create upload (browser)" do
    test "shows the real validation error instead of crashing", %{conn: conn} do
      path =
        Path.join(
          System.tmp_dir!(),
          "upload_test_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(path, "PK\x03\x04 not really a zip")
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{
        path: path,
        filename: "evil.zip",
        content_type: "application/zip"
      }

      conn =
        conn
        |> login("dave@example.com")
        |> post(~p"/uploads", upload: %{"kind" => "sub", "upload" => upload})

      body = html_response(conn, 200)
      assert body =~ "zip archives are not supported"
    end
  end
end

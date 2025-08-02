defmodule InkfishWeb.BucketControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  describe "index" do
    setup [:create_cs101]

    test "lists all buckets", %{conn: conn, course: course} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/staff/courses/#{course}/buckets")

      assert html_response(conn, 200) =~ "Listing Buckets"
    end
  end

  describe "new bucket" do
    setup [:create_cs101]

    test "renders form", %{conn: conn, course: course} do
      conn =
        conn
        |> login("bob@example.com")
        |> get(~p"/staff/courses/#{course}/buckets/new")

      assert html_response(conn, 200) =~ "New Bucket"
    end
  end

  describe "create bucket" do
    setup [:create_cs101]

    test "redirects to show when data is valid", %{conn: conn, course: course} do
      params = params_with_assocs(:bucket)

      conn =
        conn
        |> login("bob@example.com")
        |> post(~p"/staff/courses/#{course}/buckets",
          bucket: params
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/buckets/#{id}"

      conn = get(conn, ~p"/staff/buckets/#{id}")
      assert html_response(conn, 200) =~ "Show Bucket"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      conn =
        conn
        |> login("bob@example.com")
        |> post(~p"/staff/courses/#{course}/buckets",
          bucket: %{}
        )

      assert html_response(conn, 200) =~ "New Bucket"
    end
  end

  describe "edit bucket" do
    setup [:create_cs101]

    test "renders form for editing chosen bucket", %{conn: conn, bucket: bucket} do
      conn =
        conn
        |> login("bob@example.com")
        |> get(~p"/staff/buckets/#{bucket}/edit")

      assert html_response(conn, 200) =~ "Edit Bucket"
    end
  end

  describe "update bucket" do
    setup [:create_cs101]

    test "redirects when data is valid", %{conn: conn, bucket: bucket} do
      params = %{"name" => "some updated name"}

      conn =
        conn
        |> login("bob@example.com")
        |> put(~p"/staff/buckets/#{bucket}", bucket: params)

      assert redirected_to(conn) ==
               ~p"/staff/buckets/#{bucket}"

      conn = get(conn, ~p"/staff/buckets/#{bucket}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, bucket: bucket} do
      conn =
        conn
        |> login("bob@example.com")
        |> put(~p"/staff/buckets/#{bucket}",
          bucket: %{"name" => "x"}
        )

      assert html_response(conn, 200) =~ "Edit Bucket"
    end
  end

  describe "delete bucket" do
    setup [:create_cs101]

    test "deletes chosen bucket", %{conn: conn, bucket: bucket, course: course} do
      conn =
        conn
        |> login("bob@example.com")
        |> delete(~p"/staff/buckets/#{bucket}")

      assert redirected_to(conn) ==
               ~p"/staff/courses/#{course}/buckets"

      conn = get(conn, ~p"/staff/buckets/#{bucket}")
      assert redirected_to(conn) == ~p"/"
    end
  end

  defp create_cs101(_) do
    bob = Inkfish.Users.get_user_by_email!("bob@example.com")
    dave = Inkfish.Users.get_user_by_email!("dave@example.com")
    course = insert(:course, name: "CS101")
    _bob_reg = insert(:reg, course: course, user: bob, is_prof: true)
    _dave_reg = insert(:reg, course: course, user: dave, is_student: true)

    bucket = insert(:bucket, course: course)
    {:ok, bucket: bucket, course: course}
  end
end

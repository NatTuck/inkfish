defmodule InkfishWeb.Staff.BucketControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    course = insert(:course)
    staff = insert(:user)
    _sr = insert(:reg, course: course, user: staff, is_staff: true)
    bucket = insert(:bucket, course: course)
    conn = login(conn, staff)
    {:ok, conn: conn, course: course, bucket: bucket, staff: staff}
  end

  describe "index" do
    test "lists all buckets", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/buckets")
      assert html_response(conn, 200) =~ "Listing Buckets"
    end
  end

  describe "new bucket" do
    test "renders form", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/buckets/new")
      assert html_response(conn, 200) =~ "New Bucket"
    end
  end

  describe "create bucket" do
    test "redirects to show when data is valid", %{conn: conn, course: course} do
      params = params_for(:bucket)

      conn =
        post(conn, ~p"/staff/courses/#{course}/buckets",
          bucket: params
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/buckets/#{id}"

      conn = get(conn, ~p"/staff/buckets/#{id}")
      assert html_response(conn, 200) =~ "Show Bucket"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      params = %{name: ""}

      conn =
        post(conn, ~p"/staff/courses/#{course}/buckets",
          bucket: params
        )

      assert html_response(conn, 200) =~ "New Bucket"
    end
  end

  describe "edit bucket" do
    test "renders form for editing chosen bucket", %{conn: conn, bucket: bucket} do
      conn = get(conn, ~p"/staff/buckets/#{bucket}/edit")
      assert html_response(conn, 200) =~ "Edit Bucket"
    end
  end

  describe "update bucket" do
    test "redirects when data is valid", %{conn: conn, bucket: bucket} do
      params = %{name: "some updated name"}

      conn =
        put(conn, ~p"/staff/buckets/#{bucket}",
          bucket: params
        )

      assert redirected_to(conn) ==
               ~p"/staff/buckets/#{bucket}"

      conn = get(conn, ~p"/staff/buckets/#{bucket}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, bucket: bucket} do
      params = %{name: ""}

      conn =
        put(conn, ~p"/staff/buckets/#{bucket}",
          bucket: params
        )

      assert html_response(conn, 200) =~ "Edit Bucket"
    end
  end

  describe "delete bucket" do
    test "deletes chosen bucket", %{conn: conn, bucket: bucket} do
      conn = delete(conn, ~p"/staff/buckets/#{bucket}")

      assert redirected_to(conn) ==
               ~p"/staff/courses/#{bucket.course_id}/buckets"

      assert_error_sent 404, fn ->
        get(conn, ~p"/staff/buckets/#{bucket}")
      end
    end
  end
end

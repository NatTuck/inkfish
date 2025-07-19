defmodule InkfishWeb.Admin.CourseControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  def fixture(:course) do
    insert(:course)
  end

  describe "index" do
    test "lists all courses", %{conn: conn} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/admin/courses")

      assert html_response(conn, 200) =~ "Listing Courses"
    end
  end

  describe "new course" do
    test "renders form", %{conn: conn} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/admin/courses/new")

      assert html_response(conn, 200) =~ "New Course"
    end
  end

  describe "create course" do
    test "redirects to show when data is valid", %{conn: conn} do
      params = params_for(:course)

      conn =
        conn
        |> login("alice@example.com")
        |> post(~p"/admin/courses", course: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/admin/courses/#{id}"

      conn = get(conn, ~p"/admin/courses/#{id}")
      assert html_response(conn, 200) =~ "Show Course"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      params = %{name: "", solo_teamset_id: -1}

      conn =
        conn
        |> login("alice@example.com")
        |> post(~p"/admin/courses", course: params)

      assert html_response(conn, 200) =~ "New Course"
    end
  end

  describe "edit course" do
    setup [:create_course]

    test "renders form for editing chosen course", %{conn: conn, course: course} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/admin/courses/#{course}/edit")

      assert html_response(conn, 200) =~ "Edit Course"
    end
  end

  describe "update course" do
    setup [:create_course]

    test "redirects when data is valid", %{conn: conn, course: course} do
      params = %{"name" => "Updated course"}

      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/admin/courses/#{course}", course: params)

      assert redirected_to(conn) ==
               ~p"/admin/courses/#{course}"

      conn = get(conn, ~p"/admin/courses/#{course}")
      assert html_response(conn, 200) =~ "Updated course"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      params = %{name: "", solo_teamset_id: -1}

      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/admin/courses/#{course}", course: params)

      assert html_response(conn, 200) =~ "Edit Course"
    end
  end

  describe "delete course" do
    setup [:create_course]

    test "deletes chosen course", %{conn: conn, course: course} do
      conn =
        conn
        |> login("alice@example.com")
        |> delete(~p"/admin/courses/#{course}")

      assert redirected_to(conn) == ~p"/admin/courses"

      conn = get(conn, ~p"/admin/courses/#{course}")
      assert redirected_to(conn) == ~p"/"
    end
  end

  defp create_course(_) do
    course = fixture(:course)
    {:ok, course: course}
  end
end

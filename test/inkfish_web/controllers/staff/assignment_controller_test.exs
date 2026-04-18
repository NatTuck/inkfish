defmodule InkfishWeb.Staff.AssignmentControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  def fixture(:assignment) do
    insert(:assignment)
  end

  defp create_assignment(_) do
    assignment = fixture(:assignment)
    {:ok, assignment: assignment}
  end

  defp create_stock_course(_) do
    stock = stock_course()
    {:ok, stock}
  end

  describe "new assignment" do
    setup [:create_stock_course]

    test "renders form", %{conn: conn, staff: staff, bucket: bucket} do
      conn =
        conn
        |> login(staff)
        |> get(~p"/staff/buckets/#{bucket}/assignments/new")

      assert html_response(conn, 200) =~ "New Assignment"
    end
  end

  describe "create assignment" do
    setup [:create_stock_course]

    test "redirects to show when data is valid", %{
      conn: conn,
      staff: staff,
      bucket: bucket
    } do
      params = params_with_assocs(:assignment, bucket: bucket)

      conn =
        conn
        |> login(staff)
        |> post(~p"/staff/buckets/#{bucket}/assignments",
          assignment: params
        )

      assert %{id: id} = redirected_params(conn)

      assert redirected_to(conn) ==
               ~p"/staff/assignments/#{id}"

      conn = get(conn, ~p"/staff/assignments/#{id}")
      assert html_response(conn, 200) =~ "Show Assignment"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      bucket: bucket,
      staff: staff
    } do
      params = %{bucket_id: -1, name: ""}

      conn =
        conn
        |> login(staff)
        |> post(~p"/staff/buckets/#{bucket}/assignments",
          assignment: params
        )

      assert html_response(conn, 200) =~ "New Assignment"
    end
  end

  describe "edit assignment" do
    setup [:create_assignment]

    test "renders form for editing chosen assignment", %{
      conn: conn,
      assignment: assignment
    } do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/staff/assignments/#{assignment}/edit")

      assert html_response(conn, 200) =~ "Edit Assignment"
    end
  end

  describe "update assignment" do
    setup [:create_assignment]

    test "redirects when data is valid", %{conn: conn, assignment: assignment} do
      params = %{name: "Assignment #z"}

      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/staff/assignments/#{assignment}",
          assignment: params
        )

      assert redirected_to(conn) ==
               ~p"/staff/assignments/#{assignment}"

      conn = get(conn, ~p"/staff/assignments/#{assignment}")
      assert html_response(conn, 200) =~ "Assignment #z"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      assignment: assignment
    } do
      params = %{bucket_id: -1, name: ""}

      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/staff/assignments/#{assignment}",
          assignment: params
        )

      assert html_response(conn, 200) =~ "Edit Assignment"
    end
  end

  describe "delete assignment" do
    setup [:create_assignment]

    test "deletes chosen assignment", %{conn: conn, assignment: assignment} do
      conn =
        conn
        |> login("alice@example.com")
        |> delete(~p"/staff/assignments/#{assignment}")

      assert redirected_to(conn) ==
               ~p"/staff/courses/#{conn.assigns[:course]}"

      conn = get(conn, ~p"/staff/assignments/#{assignment}")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "rerun_script_grades" do
    setup [:create_stock_course]

    import Mimic

    test "staff user can rerun script grades", %{
      conn: conn,
      staff: staff,
      assignment: assignment,
      sub: _sub
    } do
      Mimic.copy(Inkfish.Subs)

      expect(Inkfish.Subs, :autograde!, fn _sub -> :ok end)

      conn =
        conn
        |> login(staff)
        |> post(~p"/staff/assignments/#{assignment}/rerun_script_grades")

      assert redirected_to(conn) == ~p"/staff/assignments/#{assignment}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Script grades rerun started"

      verify!()
    end

    test "non-staff user cannot rerun script grades", %{
      conn: conn,
      assignment: assignment
    } do
      student = Inkfish.Users.get_user_by_email!("dave@example.com")

      conn =
        conn
        |> login(student)
        |> post(~p"/staff/assignments/#{assignment}/rerun_script_grades")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "recalc_grades" do
    setup [:create_stock_course]

    test "staff user can recalc grades", %{
      conn: conn,
      staff: staff,
      assignment: assignment
    } do
      conn =
        conn
        |> login(staff)
        |> post(~p"/staff/assignments/#{assignment}/recalc_grades")

      assert redirected_to(conn) == ~p"/staff/assignments/#{assignment}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Grade totals recalculated"
    end

    test "recalculates feedback grade scores from line comments", %{
      conn: conn,
      staff: staff,
      assignment: assignment,
      sub: _sub,
      grade: grade
    } do
      gcol = grade.grade_column

      _gcol =
        Inkfish.Repo.update!(
          Ecto.Changeset.change(gcol, base: Decimal.new("40.0"))
        )

      _lc1 =
        insert(:line_comment,
          grade: grade,
          user: staff,
          line: 1,
          path: "main.c",
          text: "Good work",
          points: Decimal.new("5.0")
        )

      _lc2 =
        insert(:line_comment,
          grade: grade,
          user: staff,
          line: 2,
          path: "main.c",
          text: "Minor issue",
          points: Decimal.new("-2.0")
        )

      conn =
        conn
        |> login(staff)
        |> post(~p"/staff/assignments/#{assignment}/recalc_grades")

      assert redirected_to(conn) == ~p"/staff/assignments/#{assignment}"

      updated_grade = Inkfish.Repo.get(Inkfish.Grades.Grade, grade.id)
      expected_score = Decimal.add(Decimal.new("40.0"), Decimal.new("3.0"))
      assert Decimal.compare(updated_grade.score, expected_score) == :eq
    end

    test "recalculates sub total scores", %{
      conn: conn,
      staff: staff,
      assignment: assignment,
      sub: sub,
      grade: grade,
      grade_column: grade_column,
      confirmed_grade: confirmed_grade
    } do
      Inkfish.Repo.update!(
        Ecto.Changeset.change(grade_column, base: Decimal.new("35.0"))
      )

      # Set the number grade score to 0 so total is just feedback grade
      Inkfish.Repo.update!(
        Ecto.Changeset.change(confirmed_grade, score: Decimal.new("0.0"))
      )

      Inkfish.Repo.update!(
        Ecto.Changeset.change(sub, score: Decimal.new("20.0"))
      )

      # Confirm the feedback grade so its score is calculated
      {:ok, _} = Inkfish.Grades.confirm_grade(grade.id)

      conn =
        conn
        |> login(staff)
        |> post(~p"/staff/assignments/#{assignment}/recalc_grades")

      assert redirected_to(conn) == ~p"/staff/assignments/#{assignment}"

      updated_sub = Inkfish.Repo.get(Inkfish.Subs.Sub, sub.id)
      assert Decimal.compare(updated_sub.score, Decimal.new("35.0")) == :eq
    end

    test "non-staff user cannot recalc grades", %{
      conn: conn,
      assignment: assignment
    } do
      student = Inkfish.Users.get_user_by_email!("dave@example.com")

      conn =
        conn
        |> login(student)
        |> post(~p"/staff/assignments/#{assignment}/recalc_grades")

      assert redirected_to(conn) == ~p"/"
    end
  end
end

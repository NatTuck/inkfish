defmodule Inkfish.GradesTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Grades

  describe "grades" do
    alias Inkfish.Grades.Grade

    def grade_fixture(attrs \\ %{}) do
      insert(:grade, attrs)
    end

    test "list_grades/0 returns all grades" do
      grade = grade_fixture()
      assert drop_assocs(Grades.list_grades()) == drop_assocs([grade])
    end

    test "get_grade!/1 returns the grade with given id" do
      grade = grade_fixture()
      assert drop_assocs(Grades.get_grade!(grade.id)) == drop_assocs(grade)
    end

    test "create_grade/1 with valid data creates a grade" do
      params = params_with_assocs(:grade)
      assert {:ok, %Grade{} = grade} = Grades.create_grade(params)
      assert grade.score == Decimal.new("45.7")
    end

    test "create_grade/1 with invalid data returns error changeset" do
      params = %{}
      assert {:error, %Ecto.Changeset{}} = Grades.create_grade(params)
    end

    test "update_grade/2 with valid data updates the grade" do
      grade = grade_fixture()
      params = %{score: "25.1"}
      assert {:ok, %Grade{} = grade} = Grades.update_grade(grade, params)
      assert grade.score == Decimal.new("25.1")
    end

    test "update_grade/2 with invalid data returns error changeset" do
      grade = grade_fixture()
      params = %{score: "", sub_id: ""}
      assert {:error, %Ecto.Changeset{}} = Grades.update_grade(grade, params)
      assert drop_assocs(grade) == drop_assocs(Grades.get_grade!(grade.id))
    end

    test "delete_grade/1 deletes the grade" do
      grade = grade_fixture()
      assert {:ok, %Grade{}} = Grades.delete_grade(grade)
      assert_raise Ecto.NoResultsError, fn -> Grades.get_grade!(grade.id) end
    end

    test "change_grade/1 returns a grade changeset" do
      grade = grade_fixture()
      assert %Ecto.Changeset{} = Grades.change_grade(grade)
    end
  end

  describe "confirmation workflow" do
    alias Inkfish.Grades.Grade

    test "create_grade sets confirmed=true for non-feedback grades" do
      sub = insert(:sub)

      grade_column =
        insert(:grade_column, kind: "number", assignment: sub.assignment)

      params = %{
        sub_id: sub.id,
        grade_column_id: grade_column.id,
        score: Decimal.new("42.0")
      }

      assert {:ok, %Grade{} = grade} = Grades.create_grade(params)
      assert grade.confirmed == true
      assert grade.score == Decimal.new("42.0")
    end

    test "create_grade sets confirmed=false for feedback grades" do
      sub = insert(:sub)

      grade_column =
        insert(:grade_column, kind: "feedback", assignment: sub.assignment)

      params = %{
        sub_id: sub.id,
        grade_column_id: grade_column.id,
        score: nil
      }

      assert {:ok, %Grade{} = grade} = Grades.create_grade(params)
      assert grade.confirmed == false
      assert grade.score == nil
    end

    test "confirm_grade/1 sets confirmed=true and calculates score" do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      # Add a line comment
      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "Style issue"
      )

      assert grade.confirmed == false
      assert grade.score == nil

      assert {:ok, %Grade{} = confirmed_grade} = Grades.confirm_grade(grade.id)
      assert confirmed_grade.confirmed == true
      assert confirmed_grade.score == Decimal.new("35.0")
    end

    test "unconfirm_grade/1 sets confirmed=false and clears score" do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade

      assert confirmed_grade.confirmed == true
      assert confirmed_grade.score != nil

      assert {:ok, %Grade{} = unconfirmed_grade} =
               Grades.unconfirm_grade(confirmed_grade.id)

      assert unconfirmed_grade.confirmed == false
      assert unconfirmed_grade.score == nil
    end

    test "confirm_grade/1 returns error for non-existent grade" do
      assert {:error, :not_found} = Grades.confirm_grade(999_999)
    end

    test "unconfirm_grade/1 returns error for non-existent grade" do
      assert {:error, :not_found} = Grades.unconfirm_grade(999_999)
    end
  end

  describe "update_feedback_score with confirmation" do
    alias Inkfish.Grades.Grade

    test "calculates and stores score when grade is confirmed" do
      stock = stock_course()
      staff = stock.staff

      # Create a confirmed feedback grade
      grade_column =
        insert(:grade_column, kind: "feedback", assignment: stock.assignment)

      {:ok, grade} =
        Grades.create_grade(%{
          sub_id: stock.sub.id,
          grade_column_id: grade_column.id,
          confirmed: true
        })

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "Style issue"
      )

      assert {:ok, %Grade{} = updated_grade} =
               Grades.update_feedback_score(grade.id)

      assert updated_grade.confirmed == true
      assert updated_grade.score == Decimal.new("35.0")
    end

    test "sets score to nil when grade is unconfirmed" do
      stock = stock_course()
      staff = stock.staff
      grade = stock.grade

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "Style issue"
      )

      assert grade.confirmed == false

      assert {:ok, %Grade{} = updated_grade} =
               Grades.update_feedback_score(grade.id)

      assert updated_grade.confirmed == false
      assert updated_grade.score == nil
    end

    test "recalculates score after confirming" do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "Style issue"
      )

      # Initially unconfirmed, score should be nil
      assert {:ok, %Grade{} = grade} = Grades.update_feedback_score(grade.id)
      assert grade.score == nil

      # Confirm and recalculate
      {:ok, confirmed} = Grades.confirm_grade(grade.id)
      assert confirmed.score == Decimal.new("35.0")
    end
  end

  describe "confirmed? helper" do
    alias Inkfish.Grades.Grade

    test "returns true when grade is confirmed" do
      grade = insert(:grade, confirmed: true)
      assert Grade.confirmed?(grade) == true
    end

    test "returns false when grade is unconfirmed" do
      grade = insert(:grade, confirmed: false)
      assert Grade.confirmed?(grade) == false
    end
  end

  describe "put_grade_with_comments" do
    alias Inkfish.Grades.Grade

    test "with invalid line comment path returns error" do
      sub = insert(:sub)
      user = insert(:user)

      gcol =
        insert(:grade_column, %{assignment: sub.assignment, kind: "feedback"})

      params = %{
        "sub_id" => sub.id,
        "grade_column_id" => gcol.id,
        "line_comments" => [
          %{
            "path" => "nonexistent/file.txt",
            "line" => 1,
            "points" => -5,
            "text" => "invalid path"
          }
        ]
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               Grades.put_grade_with_comments(params, user)

      assert changeset.errors != []
    end

    test "with valid line comment path creates grade with comments" do
      sub = insert(:sub)
      user = insert(:user)

      gcol =
        insert(:grade_column, %{assignment: sub.assignment, kind: "feedback"})

      params = %{
        "sub_id" => sub.id,
        "grade_column_id" => gcol.id,
        "line_comments" => [
          %{
            "path" => "Ω_grading_extra.txt",
            "line" => 1,
            "points" => -5,
            "text" => "valid path"
          }
        ]
      }

      assert {:ok, %Grade{} = grade} =
               Grades.put_grade_with_comments(params, user)

      assert length(grade.line_comments) == 1
    end
  end

  describe "grade_columns" do
    alias Inkfish.Grades.GradeColumn

    def grade_column_fixture(attrs \\ %{}) do
      insert(:grade_column, attrs)
    end

    test "list_grade_columns/0 returns all grade_columns" do
      grade_column = grade_column_fixture()

      assert drop_assocs(Grades.list_grade_columns()) ==
               drop_assocs([grade_column])
    end

    test "get_grade_column!/1 returns the grade_column with given id" do
      grade_column = grade_column_fixture()

      assert drop_assocs(Grades.get_grade_column!(grade_column.id)) ==
               drop_assocs(grade_column)
    end

    test "create_grade_column/1 with valid data creates a grade_column" do
      params = params_with_assocs(:grade_column)

      assert {:ok, %GradeColumn{} = grade_column} =
               Grades.create_grade_column(params)

      assert grade_column.kind == "number"
      assert grade_column.name == "Number Grade"
      assert grade_column.points == Decimal.new("50.0")
      assert grade_column.base == Decimal.new("40.0")
    end

    test "create_grade_column/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Grades.create_grade_column(%{})
    end

    test "update_grade_column/2 with valid data updates the grade_column" do
      grade_column = grade_column_fixture()
      params = %{name: "Updated", base: "30.0"}

      assert {:ok, %GradeColumn{} = gc1} =
               Grades.update_grade_column(grade_column, params)

      assert gc1.kind == grade_column.kind
      assert gc1.name == "Updated"
      assert gc1.params == grade_column.params
      assert gc1.points == grade_column.points
      assert gc1.base == Decimal.new("30.0")
    end

    test "update_grade_column/2 with invalid data returns error changeset" do
      grade_column = grade_column_fixture()
      params = %{points: ""}

      assert {:error, %Ecto.Changeset{}} =
               Grades.update_grade_column(grade_column, params)

      assert drop_assocs(grade_column) ==
               drop_assocs(Grades.get_grade_column!(grade_column.id))
    end

    test "delete_grade_column/1 deletes the grade_column" do
      grade_column = grade_column_fixture()
      assert {:ok, %GradeColumn{}} = Grades.delete_grade_column(grade_column)

      assert_raise Ecto.NoResultsError, fn ->
        Grades.get_grade_column!(grade_column.id)
      end
    end

    test "change_grade_column/1 returns a grade_column changeset" do
      grade_column = grade_column_fixture()
      assert %Ecto.Changeset{} = Grades.change_grade_column(grade_column)
    end
  end
end

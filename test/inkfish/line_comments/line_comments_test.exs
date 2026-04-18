defmodule Inkfish.LineCommentsTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.LineComments
  alias Inkfish.LineComments.LineComment

  describe "line_comments" do
    alias Inkfish.LineComments.LineComment

    def line_comment_fixture(attrs \\ %{}) do
      insert(:line_comment, attrs)
    end

    test "list_line_comments/0 returns all line_comments" do
      line_comment = line_comment_fixture()
      xs = LineComments.list_line_comments()
      ys = [line_comment]
      assert drop_assocs(xs) == drop_assocs(ys)
    end

    test "get_line_comment!/1 returns the line_comment with given id" do
      line_comment = line_comment_fixture()

      assert drop_assocs(LineComments.get_line_comment!(line_comment.id)) ==
               drop_assocs(line_comment)
    end

    test "create_line_comment/1 with valid data creates a line_comment" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "hw03/main.c",
        line: 10,
        points: Decimal.new("-5.0"),
        text: "Don't mix tabs and spaces"
      }

      assert {:ok, %LineComment{} = line_comment} =
               LineComments.create_line_comment(params, ["hw03/main.c"])

      assert line_comment.line == 10
      assert line_comment.path == "hw03/main.c"
      assert line_comment.points == Decimal.new("-5.0")
      assert line_comment.text == "Don't mix tabs and spaces"
    end

    test "create_line_comment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = LineComments.create_line_comment(%{})
    end

    test "create_line_comment/1 with path not in submission returns error" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "nonexistent/file.txt",
        line: 1,
        points: -5,
        text: "test"
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               LineComments.create_line_comment(params, :auto)

      assert "path does not exist in submission" in errors_on(changeset).path
    end

    test "create_line_comment/1 with valid path in submission succeeds" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "hw03/main.c",
        line: 1,
        points: -5,
        text: "test"
      }

      assert {:ok, %LineComment{} = lc} =
               LineComments.create_line_comment(params, ["hw03/main.c"])

      assert lc.path == "hw03/main.c"
    end

    test "update_line_comment/2 with valid data updates the line_comment" do
      line_comment = line_comment_fixture()
      attrs = %{line: 43, points: "25.0"}

      assert {:ok, %LineComment{} = lc} =
               LineComments.update_line_comment(line_comment, attrs)

      assert lc.line == 43
      assert lc.path == line_comment.path
      assert lc.points == Decimal.new("25.0")
      assert lc.text == line_comment.text
    end

    test "update_line_comment/2 with invalid data returns error changeset" do
      line_comment = line_comment_fixture()
      params = %{grade_id: nil}

      assert {:error, %Ecto.Changeset{}} =
               LineComments.update_line_comment(line_comment, params)

      assert drop_assocs(line_comment) ==
               drop_assocs(LineComments.get_line_comment!(line_comment.id))
    end

    test "delete_line_comment/1 deletes the line_comment" do
      line_comment = line_comment_fixture()

      assert {:ok, %LineComment{}} =
               LineComments.delete_line_comment(line_comment)

      assert_raise Ecto.NoResultsError, fn ->
        LineComments.get_line_comment!(line_comment.id)
      end
    end

    test "change_line_comment/1 returns a line_comment changeset" do
      line_comment = line_comment_fixture()
      assert %Ecto.Changeset{} = LineComments.change_line_comment(line_comment)
    end
  end

  describe "filter_for_display" do
    alias Inkfish.LineComments.LineComment

    test "invalid path line comments are shown at line 1 in omega file" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      invalid_lc =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "nonexistent/file.txt",
          line: 42,
          points: -5,
          text: "This file doesn't exist"
        })

      valid_lc =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "Ω_grading_extra.txt",
          line: 10,
          points: -3,
          text: "This is valid"
        })

      valid_paths = ["Ω_grading_extra.txt"]

      {invalid, valid} =
        LineComments.filter_for_display([invalid_lc, valid_lc], valid_paths)

      assert length(invalid) == 1
      assert hd(invalid).path == "Ω_grading_extra.txt"
      assert hd(invalid).line == 1

      assert length(valid) == 1
      assert hd(valid).path == "Ω_grading_extra.txt"
      assert hd(valid).line == 10
    end

    test "invalid line numbers are adjusted to last valid line" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      lc_with_invalid_line =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "hw03/main.c",
          line: 100,
          points: -5,
          text: "Line exceeds file length"
        })

      lc_with_valid_line =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "hw03/main.c",
          line: 10,
          points: -3,
          text: "Valid line"
        })

      valid_paths = ["hw03/main.c"]
      valid_line_counts = %{"hw03/main.c" => 20}

      {invalid, valid} =
        LineComments.filter_for_display(
          [lc_with_invalid_line, lc_with_valid_line],
          valid_paths,
          valid_line_counts
        )

      assert length(invalid) == 0
      assert length(valid) == 2

      adjusted_lc =
        Enum.find(valid, fn lc -> lc.text == "Line exceeds file length" end)

      assert adjusted_lc.line == 20

      unchanged_lc = Enum.find(valid, fn lc -> lc.text == "Valid line" end)
      assert unchanged_lc.line == 10
    end
  end

  describe "comment operations on unconfirmed grade" do
    test "create_line_comment succeeds on unconfirmed grade" do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      assert grade.confirmed == false

      params = %{
        grade_id: grade.id,
        user_id: staff.id,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: -5,
        text: "Test comment"
      }

      assert {:ok, %LineComment{} = lc} =
               LineComments.create_line_comment(params, :auto, :auto)

      assert lc.text == "Test comment"
    end

    test "update_line_comment succeeds on unconfirmed grade" do
      stock = stock_course()
      grade = stock.grade
      user = insert(:user)

      line_comment =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "Ω_grading_extra.txt",
          line: 3,
          text: "Original"
        })

      assert {:ok, %LineComment{} = lc} =
               LineComments.update_line_comment(line_comment, %{text: "Updated"})

      assert lc.text == "Updated"
    end

    test "delete_line_comment succeeds on unconfirmed grade" do
      stock = stock_course()
      grade = stock.grade
      user = insert(:user)

      line_comment =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "Ω_grading_extra.txt",
          line: 3,
          text: "To delete"
        })

      assert {:ok, %LineComment{}} =
               LineComments.delete_line_comment(line_comment)

      assert_raise Ecto.NoResultsError, fn ->
        LineComments.get_line_comment!(line_comment.id)
      end
    end
  end

  describe "comment operations on confirmed grade" do
    test "create_line_comment fails on confirmed grade" do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade
      user = insert(:user)

      assert confirmed_grade.confirmed == true

      params = %{
        grade_id: confirmed_grade.id,
        user_id: user.id,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: -5,
        text: "Should fail"
      }

      assert {:error, :grade_already_confirmed} =
               LineComments.create_line_comment(params, :auto, :auto)
    end

    test "update_line_comment fails on confirmed grade" do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade
      user = insert(:user)

      line_comment =
        insert(:line_comment, %{
          grade: confirmed_grade,
          user: user,
          path: "Ω_grading_extra.txt",
          line: 3,
          text: "Original"
        })

      assert {:error, :grade_already_confirmed} =
               LineComments.update_line_comment(line_comment, %{text: "Updated"})
    end

    test "delete_line_comment fails on confirmed grade" do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade
      user = insert(:user)

      line_comment =
        insert(:line_comment, %{
          grade: confirmed_grade,
          user: user,
          path: "Ω_grading_extra.txt",
          line: 3,
          text: "To delete"
        })

      assert {:error, :grade_already_confirmed} =
               LineComments.delete_line_comment(line_comment)
    end
  end

  describe "line number validation" do
    alias Inkfish.LineComments.LineComment

    test "create_line_comment/1 with line exceeding file length returns error" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "hw03/main.c",
        line: 100,
        points: -5,
        text: "test"
      }

      valid_paths = ["hw03/main.c"]
      valid_line_counts = %{"hw03/main.c" => 20}

      assert {:error, %Ecto.Changeset{} = changeset} =
               LineComments.create_line_comment(
                 params,
                 valid_paths,
                 valid_line_counts
               )

      assert "exceeds file length (max line: 20)" in errors_on(changeset).line
    end

    test "create_line_comment/1 with valid line succeeds" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "hw03/main.c",
        line: 10,
        points: -5,
        text: "test"
      }

      valid_paths = ["hw03/main.c"]
      valid_line_counts = %{"hw03/main.c" => 20}

      assert {:ok, %LineComment{} = lc} =
               LineComments.create_line_comment(
                 params,
                 valid_paths,
                 valid_line_counts
               )

      assert lc.line == 10
      assert lc.path == "hw03/main.c"
    end

    test "update_line_comment changeset validates line numbers" do
      line_comment = insert(:line_comment, %{path: "hw03/main.c", line: 10})
      valid_line_counts = %{"hw03/main.c" => 20}

      changeset =
        LineComment.changeset(
          line_comment,
          %{line: 100},
          nil,
          valid_line_counts
        )

      assert {:error, changeset} = Repo.update(changeset)
      assert "exceeds file length (max line: 20)" in errors_on(changeset).line
    end

    test "update_line_comment changeset allows valid line numbers" do
      line_comment = insert(:line_comment, %{path: "hw03/main.c", line: 10})
      valid_line_counts = %{"hw03/main.c" => 20}

      changeset =
        LineComment.changeset(
          line_comment,
          %{line: 15, points: "25.0"},
          nil,
          valid_line_counts
        )

      assert {:ok, lc} = Repo.update(changeset)
      assert lc.line == 15
    end
  end

  describe "text validation" do
    alias Inkfish.LineComments.LineComment

    test "create_line_comment/1 with empty text returns error" do
      stock = stock_course()
      grade = stock.grade
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: -5,
        text: ""
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               LineComments.create_line_comment(params, :auto, :auto)

      assert "Comment text cannot be empty" in errors_on(changeset).text
    end

    test "create_line_comment/1 with whitespace-only text returns error" do
      stock = stock_course()
      grade = stock.grade
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: -5,
        text: "   \t\n  "
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               LineComments.create_line_comment(params, :auto, :auto)

      assert "Comment text cannot be empty" in errors_on(changeset).text
    end

    test "create_line_comment/1 with valid text succeeds" do
      stock = stock_course()
      grade = stock.grade
      user = insert(:user)

      params = %{
        grade_id: grade.id,
        user_id: user.id,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: -5,
        text: "Good comment"
      }

      assert {:ok, %LineComment{} = lc} =
               LineComments.create_line_comment(params, :auto, :auto)

      assert lc.text == "Good comment"
    end

    test "update_line_comment/2 with empty text returns error" do
      stock = stock_course()
      grade = stock.grade
      user = insert(:user)

      line_comment =
        insert(:line_comment, %{
          grade: grade,
          user: user,
          path: "Ω_grading_extra.txt",
          line: 3,
          text: "Original text"
        })

      attrs = %{text: ""}

      assert {:error, %Ecto.Changeset{} = changeset} =
               LineComments.update_line_comment(line_comment, attrs)

      assert "Comment text cannot be empty" in errors_on(changeset).text
    end

    test "existing line comments with empty text can be displayed" do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      # Bypass validation to simulate legacy data
      {:ok, lc} =
        %LineComment{
          grade_id: grade.id,
          user_id: user.id,
          path: "Ω_grading_extra.txt",
          line: 3,
          points: Decimal.new("-5"),
          text: ""
        }
        |> Repo.insert()

      fetched = LineComments.get_line_comment!(lc.id)
      assert fetched.text == ""
    end
  end
end

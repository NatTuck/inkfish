defmodule Inkfish.LineComments.AutomatedMarkingTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.LineComments

  describe "mark_automated/1" do
    test "wraps text in the bot marker" do
      assert LineComments.mark_automated("Nice try") == "🤖 Nice try 🤖"
    end

    test "is idempotent" do
      text = LineComments.mark_automated("Nice try")
      assert LineComments.mark_automated(text) == text
    end

    test "trims text" do
      assert LineComments.mark_automated("  spaces  ") == "🤖 spaces 🤖"
    end

    test "leaves nil alone" do
      assert LineComments.mark_automated(nil) == nil
    end
  end

  describe "automated_text?/1" do
    test "is true for marked text" do
      assert LineComments.automated_text?("🤖 hello 🤖")
    end

    test "is false for unmarked text" do
      refute LineComments.automated_text?("hello")
      refute LineComments.automated_text?("🤖 hello")
    end
  end

  describe "mark_automated_attrs/2" do
    test "marks string keyed text from the api" do
      attrs = %{"text" => "From a bot", "points" => "-1.0"}

      marked = LineComments.mark_automated_attrs(attrs, source: :api)

      assert marked["text"] == "🤖 From a bot 🤖"
      assert marked["points"] == "-1.0"
    end

    test "marks atom keyed text from the api" do
      marked =
        LineComments.mark_automated_attrs(%{text: "From a bot"}, source: :api)

      assert marked.text == "🤖 From a bot 🤖"
    end

    test "leaves text alone for other sources" do
      attrs = %{"text" => "From a"}

      assert LineComments.mark_automated_attrs(attrs, []) == attrs
      assert LineComments.mark_automated_attrs(attrs, source: :browser) == attrs
    end

    test "le attrs without text alone" do
      attrs = %{"points" => "-1.0"}

      assert LineComments.mark_automated_attrs(attrs, source: :api) == attrs
    end
  end

  describe "create_line_comment/4" do
    defp comment_params(text) do
      grade = insert(:grade, confirmed: false)
      user = insert(:user)

      %{
        grade_id: grade.id,
        user_id: user.id,
        path: "hw03/main.c",
        line: 10,
        points: Decimal.new("-5.0"),
        text: text
      }
    end

    test "with source: :api marks the text as machine written" do
      params = comment_params("From a bot")

      assert {:ok, comment} =
               LineComments.create_line_comment(
                 params,
                 ["hw03/main.c"],
                 nil,
                 source: :api
               )

      assert comment.text == "🤖 From a bot 🤖"
    end

    test "without source leaves the text alone" do
      params = comment_params("From a human")

      assert {:ok, comment} =
               LineComments.create_line_comment(params, ["hw03/main.c"])

      assert comment.text == "From a human"
    end
  end
end

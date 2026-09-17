defmodule InkfishWeb.ViewHelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML, only: [safe_to_string: 1]

  alias InkfishWeb.ViewHelpers, as: V

  describe "trusted_markdown/1" do
    test "renders the empty placeholder for nil" do
      assert V.trusted_markdown(nil) == "∅"
    end

    test "renders basic markdown" do
      assert V.trusted_markdown("**bold**") |> safe_to_string() =~
               "<strong>bold</strong>"
    end

    test "renders raw HTML for trusted content" do
      assert V.trusted_markdown("<strong>hi</strong>") |> safe_to_string() =~
               "<strong>hi</strong>"
    end

    test "renders GFM tables" do
      html =
        V.trusted_markdown("| a | b |\n|---|---|\n| 1 | 2 |")
        |> safe_to_string()

      assert html =~ "<table>"
      assert html =~ "<th>a</th>"
    end

    test "renders GFM strikethrough" do
      assert V.trusted_markdown("~~gone~~") |> safe_to_string() =~
               "<del>gone</del>"
    end

    test "autolinks bare URLs" do
      assert V.trusted_markdown("see https://example.com") |> safe_to_string() =~
               ~s(<a href="https://example.com">)
    end

    test "applies smart punctuation" do
      assert V.trusted_markdown(~s("Hello" -- world...)) |> safe_to_string() =~
               "“Hello”"
    end
  end

  describe "sanitize_markdown/1" do
    test "renders the empty placeholder for nil" do
      assert V.sanitize_markdown(nil) == "∅"
    end

    test "keeps basic formatting" do
      assert V.sanitize_markdown("**bold**") |> safe_to_string() =~
               "<strong>bold</strong>"
    end

    test "strips script tags but keeps the text" do
      html =
        V.sanitize_markdown("<script>alert(1)</script>ok") |> safe_to_string()

      refute html =~ "<script>"
      assert html =~ "ok"
    end

    test "strips javascript: URLs" do
      html = V.sanitize_markdown("[x](javascript:alert(1))") |> safe_to_string()

      refute html =~ "javascript:"
      assert html =~ "x"
    end
  end
end

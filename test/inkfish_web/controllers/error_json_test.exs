defmodule InkfishWeb.ErrorJSONTest do
  use InkfishWeb.ConnCase, async: true

  test "renders 404.html" do
    assert render("404.html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render("500.html", []) == "Internal Server Error"
  end

  defp render(page, assigns) do
    InkfishWeb.ErrorJSON.render(page, assigns)[:errors][:detail]
  end
end

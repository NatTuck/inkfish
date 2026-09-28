defmodule InkfishWeb.CourseFeedbackIndicatorTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    stock = stock_course()
    conn = login(conn, stock.student)
    {:ok, conn: conn, stock: stock}
  end

  test "links draft feedback items from the assignment list", %{
    conn: conn,
    stock: stock
  } do
    insert(:line_comment,
      grade: stock.grade,
      path: "hw03/main.c",
      line: 3,
      points: Decimal.new("-2.0"),
      text: "Fix this"
    )

    conn = get(conn, ~p"/courses/#{stock.course}")
    html = html_response(conn, 200)

    assert html =~ "Feedback"
    assert html =~ ~p"/subs/#{stock.sub.id}/feedback"
    assert html =~ "1 item"
    assert html =~ "1 draft"
  end

  test "shows no feedback link when there are no comments", %{
    conn: conn,
    stock: stock
  } do
    conn = get(conn, ~p"/courses/#{stock.course}")
    html = html_response(conn, 200)

    refute html =~ ~p"/subs/#{stock.sub.id}/feedback"
  end
end

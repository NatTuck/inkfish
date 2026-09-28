defmodule InkfishWeb.SubFeedbackPageTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    stock = stock_course()
    conn = login(conn, stock.student)
    {:ok, conn: conn, stock: stock}
  end

  test "shows draft feedback with the submission link", %{
    conn: conn,
    stock: stock
  } do
    insert(:line_comment,
      grade: stock.grade,
      path: "hw03/main.c",
      line: 3,
      points: Decimal.new("-2.0"),
      text: "Fix this please"
    )

    conn = get(conn, ~p"/subs/#{stock.sub}/feedback")
    html = html_response(conn, 200)

    assert html =~ "View whole submission and feedback"
    assert html =~ ~p"/subs/#{stock.sub}/files"
    assert html =~ "Fix this please"
    assert html =~ "Draft"
  end

  test "hides another student's feedback", %{conn: conn, stock: stock} do
    other = insert(:user)
    insert(:reg, course: stock.course, user: other, is_student: true)

    conn = login(conn, other)
    conn = get(conn, ~p"/subs/#{stock.sub}/feedback")

    assert redirected_to(conn) == ~p"/assignments/#{stock.assignment}"
  end
end

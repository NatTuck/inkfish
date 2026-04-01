defmodule InkfishWeb.SubmitTest do
  use PhoenixTest.Playwright.Case

  import Inkfish.Factory

  @session_options [
    store: :cookie,
    key: "_inkfish_key",
    signing_salt: "D/1gbc4j",
    extra: "SameSite=Lax"
  ]

  @tag :skip
  test "load main page", %{conn: conn} do
    student_user = insert(:user, email: "student@test.com")
    course = insert(:course)
    insert(:reg, course: course, user: student_user, is_student: true)
    bucket = insert(:bucket, course: course)
    _assignment = insert(:assignment, bucket: bucket)

    conn
    |> add_session_cookie(
      [value: %{user_id: student_user.id}],
      @session_options
    )
    |> visit("/")
    |> assert_has("title", text: "Inkfish")
  end
end

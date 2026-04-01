defmodule InkfishWeb.AttendanceFlowTest do
  use PhoenixTest.Playwright.Case

  import Inkfish.Factory

  @session_options [
    store: :cookie,
    key: "_inkfish_key",
    signing_salt: "D/1gbc4j",
    extra: "SameSite=Lax"
  ]

  describe "staff teamset page" do
    test "staff can view teamset page without active meeting", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      staff_user = insert(:user, email: "staff@test.com")
      insert(:reg, course: course, user: staff_user, is_staff: true)

      conn
      |> add_session_cookie(
        [value: %{user_id: staff_user.id}],
        @session_options
      )
      |> visit("/staff/teamsets/#{teamset.id}")
      |> assert_has("h1", text: "Teamset: #{teamset.name}")
    end

    test "staff can view teamset page with active meeting", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      _meeting =
        insert(:meeting,
          course: course,
          teamset: teamset,
          secret_code: "TESTCODE"
        )

      staff_user = insert(:user, email: "staff@test.com")
      insert(:reg, course: course, user: staff_user, is_staff: true)

      conn
      |> add_session_cookie(
        [value: %{user_id: staff_user.id}],
        @session_options
      )
      |> visit("/staff/teamsets/#{teamset.id}")
      |> assert_has("h1", text: "Teamset: #{teamset.name}")
      |> assert_has("p", text: "Code: TESTCODE")
    end
  end

  describe "student course page" do
    test "student can view course page without active meeting", %{conn: conn} do
      course = insert(:course)
      bucket = insert(:bucket, course: course)
      _assignment = insert(:assignment, bucket: bucket)

      student_user = insert(:user, email: "student@test.com")
      insert(:reg, course: course, user: student_user, is_student: true)

      conn
      |> add_session_cookie(
        [value: %{user_id: student_user.id}],
        @session_options
      )
      |> visit("/courses/#{course.id}")
      |> assert_has("h1", text: "Show Course")
      |> assert_has("li", text: course.name)
      |> assert_has("div#attendance-widget")
    end

    test "student sees no current meeting message when no meeting active", %{
      conn: conn
    } do
      course = insert(:course)

      student_user = insert(:user, email: "student@test.com")
      insert(:reg, course: course, user: student_user, is_student: true)

      conn
      |> add_session_cookie(
        [value: %{user_id: student_user.id}],
        @session_options
      )
      |> visit("/courses/#{course.id}")
      |> assert_has("p", text: "No current meeting.")
    end

    test "student can enter attendance code for active meeting", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      _meeting =
        insert(:meeting,
          course: course,
          teamset: teamset,
          secret_code: "TESTCODE"
        )

      student_user = insert(:user, email: "student@test.com")
      insert(:reg, course: course, user: student_user, is_student: true)

      conn
      |> add_session_cookie(
        [value: %{user_id: student_user.id}],
        @session_options
      )
      |> visit("/courses/#{course.id}")
      |> assert_has("div#attendance-widget")
      |> assert_has("label", text: "Enter code:")
      |> fill_in("Enter code:", with: "TESTCODE")
      |> click_button("I'm Here!")
      |> assert_has("p", text: "Present")
    end
  end
end

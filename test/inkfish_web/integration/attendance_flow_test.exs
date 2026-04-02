defmodule InkfishWeb.AttendanceFlowTest do
  use PhoenixTest.Playwright.Case

  import Inkfish.Factory

  alias PhoenixTest.Playwright
  alias PhoenixTest.Playwright.Config
  alias PlaywrightEx.Browser
  alias PlaywrightEx.BrowserContext
  alias PlaywrightEx.Page

  @session_options [
    store: :cookie,
    key: "_inkfish_key",
    signing_salt: "D/1gbc4j",
    extra: "SameSite=Lax"
  ]

  defp new_session(browser_id, user_id) do
    base_url = Application.fetch_env!(:phoenix_test, :base_url)
    timeout = Config.global(:timeout)

    {:ok, browser_context} =
      Browser.new_context(browser_id,
        base_url: base_url,
        locale: "en",
        timeout: timeout
      )

    {:ok, page} =
      BrowserContext.new_page(browser_context.guid, timeout: timeout)

    {:ok, _} =
      Page.update_subscription(page.guid,
        event: :console,
        enabled: true,
        timeout: timeout
      )

    {:ok, _} =
      Page.update_subscription(page.guid,
        event: :dialog,
        enabled: true,
        timeout: timeout
      )

    conn = %{
      context_id: browser_context.guid,
      page_id: page.guid,
      frame_id: page.main_frame.guid,
      tracing_id: browser_context.tracing.guid,
      config: Config.global()
    }

    conn = Playwright.build(conn)

    cookie =
      PhoenixTest.Playwright.CookieArgs.from_session_options(
        [value: %{user_id: user_id}],
        @session_options
      )

    {:ok, _} =
      BrowserContext.add_cookies(conn.context_id,
        cookies: [cookie],
        timeout: timeout
      )

    conn
  end

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

  describe "attendance broadcast to teamset page" do
    test "teamset page shows existing student attendance on initial load", %{
      conn: conn
    } do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      meeting =
        insert(:meeting,
          course: course,
          teamset: teamset,
          secret_code: "TESTCODE"
        )

      student = insert(:user, given_name: "Alice", surname: "Student")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      _attendance = insert(:attendance, meeting: meeting, reg: student_reg)

      staff = insert(:user)

      insert(:reg,
        course: course,
        user: staff,
        is_staff: true,
        is_student: false
      )

      conn
      |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
      |> visit("/staff/teamsets/#{teamset.id}")
      |> assert_has("h2", text: "Who's Here?")
      |> assert_has("p", text: "Code: TESTCODE")
      |> assert_has("table tbody tr td", text: "Alice Student")
      |> assert_has("table tbody tr", text: "here")
    end

    test "teamset page shows missing students who haven't checked in", %{
      conn: conn
    } do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      _meeting =
        insert(:meeting,
          course: course,
          teamset: teamset,
          secret_code: "TESTCODE"
        )

      student = insert(:user, given_name: "Bob", surname: "Absent")
      insert(:reg, course: course, user: student, is_student: true)

      staff = insert(:user)

      insert(:reg,
        course: course,
        user: staff,
        is_staff: true,
        is_student: false
      )

      conn
      |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
      |> visit("/staff/teamsets/#{teamset.id}")
      |> assert_has("h2", text: "Who's Here?")
      |> assert_has("td", text: "Bob Absent")
      |> assert_has("td", text: "missing")
    end

    @tag timeout: to_timeout(second: 10)
    test "student check-in broadcasts and updates staff's Who's Here list", %{
      conn: staff_conn,
      browser_id: browser_id
    } do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      _meeting =
        insert(:meeting,
          course: course,
          teamset: teamset,
          secret_code: "TESTCODE"
        )

      student = insert(:user, given_name: "Charlie", surname: "Checker")
      insert(:reg, course: course, user: student, is_student: true)

      staff = insert(:user)

      insert(:reg,
        course: course,
        user: staff,
        is_staff: true,
        is_student: false
      )

      staff_conn =
        staff_conn
        |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
        |> visit("/staff/teamsets/#{teamset.id}")
        |> assert_has("h2", text: "Who's Here?")
        |> assert_has("td", text: "Charlie Checker")
        |> assert_has("td", text: "missing")

      student_conn = new_session(browser_id, student.id)

      student_conn
      |> visit("/courses/#{course.id}")
      |> assert_has("label", text: "Enter code:")
      |> fill_in("Enter code:", with: "TESTCODE")
      |> click_button("I'm Here!")
      |> assert_has("p", text: "Present")

      Process.sleep(500)

      staff_conn
      |> assert_has("td", text: "Charlie Checker")
      |> assert_has("td", text: "here")
    end

    @tag timeout: to_timeout(second: 10)
    test "multiple student check-ins all appear on staff's Who's Here list", %{
      conn: staff_conn,
      browser_id: browser_id
    } do
      course = insert(:course)
      teamset = insert(:teamset, course: course)

      _meeting =
        insert(:meeting,
          course: course,
          teamset: teamset,
          secret_code: "MULTI"
        )

      student1 = insert(:user, given_name: "Dana", surname: "First")
      insert(:reg, course: course, user: student1, is_student: true)

      student2 = insert(:user, given_name: "Eve", surname: "Second")
      insert(:reg, course: course, user: student2, is_student: true)

      staff = insert(:user)

      insert(:reg,
        course: course,
        user: staff,
        is_staff: true,
        is_student: false
      )

      staff_conn =
        staff_conn
        |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
        |> visit("/staff/teamsets/#{teamset.id}")
        |> assert_has("h2", text: "Who's Here?")
        |> assert_has("td", text: "Dana First")
        |> assert_has("td", text: "missing")
        |> assert_has("td", text: "Eve Second")
        |> assert_has("td", text: "missing")

      student1_conn = new_session(browser_id, student1.id)

      student1_conn
      |> visit("/courses/#{course.id}")
      |> fill_in("Enter code:", with: "MULTI")
      |> click_button("I'm Here!")
      |> assert_has("p", text: "Present")

      Process.sleep(500)

      staff_conn
      |> assert_has("td", text: "Dana First")
      |> assert_has("td", text: "here")

      student2_conn = new_session(browser_id, student2.id)

      student2_conn
      |> visit("/courses/#{course.id}")
      |> fill_in("Enter code:", with: "MULTI")
      |> click_button("I'm Here!")
      |> assert_has("p", text: "Present")

      Process.sleep(500)

      staff_conn
      |> assert_has("td", text: "Eve Second")
      |> assert_has("td", text: "here")
    end
  end
end

defmodule InkfishWeb.GradeConfirmFlowTest do
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

  describe "staff grade edit page" do
    test "staff sees Draft badge and preview score", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: true,
          due: Inkfish.LocalTime.in_days(-1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Feedback",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: nil,
          confirmed: false
        )

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "main.c",
        line: 5,
        points: Decimal.new("-2.0"),
        text: "Bad indentation"
      )

      conn
      |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
      |> visit("/staff/grades/#{grade.id}/edit")
      |> assert_has("h1", text: "Edit Grade")
      |> assert_has("span.badge", text: "Draft")
      |> assert_has("span", text: "preview:")
    end

    test "staff sees Confirmed badge and Unlock button", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: true,
          due: Inkfish.LocalTime.in_days(-1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Code Review",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff2@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student2@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: Decimal.new("8.0"),
          confirmed: true
        )

      conn
      |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
      |> visit("/staff/grades/#{grade.id}/edit")
      |> assert_has("h1", text: "Edit Grade")
      |> assert_has("span.badge", text: "Confirmed")
      |> assert_has("button", text: "Unlock")
    end
  end

  describe "staff confirm review page" do
    test "staff can review and confirm grade", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: true,
          due: Inkfish.LocalTime.in_days(-1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Feedback",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff3@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student3@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: nil,
          confirmed: false
        )

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "main.c",
        line: 5,
        points: Decimal.new("-2.0"),
        text: "Needs improvement"
      )

      conn
      |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
      |> visit("/staff/grades/#{grade.id}/confirm-review")
      |> assert_has("h1", text: "Review and Confirm Grade")
      |> assert_has("span.badge", text: "Draft")
      |> assert_has(".card-header")
      |> click_button("Confirm Comments and Deductions")
      |> assert_has("h1", text: "Show Grade")
    end
  end

  describe "student grade view when not yet released" do
    test "student sees comments and Confirmed badge but no score before 4 days",
         %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: false,
          due: Inkfish.LocalTime.in_days(1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Feedback",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff7@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student7@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: Decimal.new("8.0"),
          confirmed: true
        )

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "main.c",
        line: 5,
        points: Decimal.new("-2.0"),
        text: "Confirmed comment visible before release"
      )

      conn
      |> add_session_cookie([value: %{user_id: student.id}], @session_options)
      |> visit("/grades/#{grade.id}")
      |> assert_has("h1", text: "Show Grade: Feedback")
      |> assert_has("span.badge", text: "Confirmed")
      |> assert_has("span", text: "Score available after grades are released")
      |> assert_has(".code-viewer")
    end

    test "student sees score after 4 days past due", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: false,
          due: Inkfish.LocalTime.in_days(-5)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Feedback",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff8@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student8@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: Decimal.new("8.0"),
          confirmed: true
        )

      conn
      |> add_session_cookie([value: %{user_id: student.id}], @session_options)
      |> visit("/grades/#{grade.id}")
      |> assert_has("h1", text: "Show Grade: Feedback")
      |> assert_has("span.badge", text: "Confirmed")
      |> assert_has("span", text: "8.0")
    end
  end

  describe "student grade view" do
    test "student sees Draft badge and no score when unconfirmed", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: true,
          due: Inkfish.LocalTime.in_days(-1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Feedback",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff4@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student4@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: nil,
          confirmed: false
        )

      conn
      |> add_session_cookie([value: %{user_id: student.id}], @session_options)
      |> visit("/grades/#{grade.id}")
      |> assert_has("h1", text: "Show Grade: Feedback")
      |> assert_has("span.badge", text: "Draft")
      |> assert_has("span", text: "Score: --")
    end

    test "student sees Confirmed badge and score when confirmed", %{conn: conn} do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: true,
          due: Inkfish.LocalTime.in_days(-1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Code Review",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff5@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student5@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: Decimal.new("8.0"),
          confirmed: true
        )

      conn
      |> add_session_cookie([value: %{user_id: student.id}], @session_options)
      |> visit("/grades/#{grade.id}")
      |> assert_has("h1", text: "Show Grade: Code Review")
      |> assert_has("span.badge", text: "Confirmed")
      |> assert_has("span", text: "8.0")
    end
  end

  describe "full confirmation workflow" do
    @tag timeout: to_timeout(second: 30)
    test "student sees score after staff confirms grade", %{
      conn: conn,
      browser_id: browser_id
    } do
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      bucket = insert(:bucket, course: course)

      assignment =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          force_show_grades: true,
          due: Inkfish.LocalTime.in_days(-1)
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: assignment,
          name: "Feedback",
          points: Decimal.new("10.0"),
          base: Decimal.new("10.0")
        )

      staff = insert(:user, email: "staff6@test.com")
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

      student = insert(:user, email: "student6@test.com")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          score: nil,
          confirmed: false
        )

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "main.c",
        line: 5,
        points: Decimal.new("-2.0"),
        text: "Draft comment"
      )

      student_conn =
        conn
        |> add_session_cookie([value: %{user_id: student.id}], @session_options)
        |> visit("/grades/#{grade.id}")
        |> assert_has("h1", text: "Show Grade: Feedback")
        |> assert_has("span.badge", text: "Draft")
        |> assert_has("span", text: "Score: --")

      staff_conn = new_session(browser_id, staff.id)

      staff_conn
      |> visit("/staff/grades/#{grade.id}/confirm-review")
      |> assert_has("h1", text: "Review and Confirm Grade")
      |> click_button("Confirm Comments and Deductions")
      |> assert_has("h1", text: "Show Grade")

      Process.sleep(500)

      student_conn
      |> visit("/grades/#{grade.id}")
      |> assert_has("span.badge", text: "Confirmed")
      |> assert_has("span", text: "8.0")
    end
  end
end

defmodule InkfishWeb.LineCommentEditTest do
  use PhoenixTest.Playwright.Case

  import Inkfish.Factory

  alias PhoenixTest.Playwright.Config
  alias PhoenixTest.Playwright.EventListener
  alias PlaywrightEx.Page

  alias Inkfish.Uploads

  @session_options [
    store: :cookie,
    key: "_inkfish_key",
    signing_salt: "D/1gbc4j",
    extra: "SameSite=Lax"
  ]

  defp upload_file do
    priv = :code.priv_dir(:inkfish)
    path = Path.join(priv, "test_data/helloc.tar.gz")
    %{path: path, filename: "helloc.tar.gz"}
  end

  defp setup_grade_with_files(_) do
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

    staff = insert(:user, email: "staff@test.com")
    insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

    student = insert(:user, email: "student@test.com")

    student_reg =
      insert(:reg, course: course, user: student, is_student: true)

    team = insert(:team, teamset: teamset, active: true)
    insert(:team_member, team: team, reg: student_reg)

    upload_attrs =
      params_with_assocs(:upload, user: student, kind: "sub")
      |> Map.put(:upload, upload_file())

    {:ok, upload} = Uploads.create_upload(upload_attrs)

    sub =
      insert(:sub,
        assignment: assignment,
        reg: student_reg,
        team: team,
        upload: upload,
        grader: nil
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
      path: "helloc/Makefile",
      line: 3,
      points: Decimal.new("-1.0"),
      text: "Missing clean target"
    )

    {:ok,
     %{
       staff: staff,
       grade: grade
     }}
  end

  defp assert_no_console_errors(agent) do
    errors = Agent.get(agent, fn errors -> Enum.reverse(errors) end)

    for {text, type} <- errors do
      if text =~ "is not defined" or text =~ "ReferenceError" or
           text =~ "TypeError" do
        flunk("JavaScript console error: #{type} - #{text}")
      end
    end

    :ok
  end

  describe "line comment creation and editing with console error detection" do
    setup [:setup_grade_with_files]

    @tag timeout: to_timeout(second: 30)
    test "staff creates new comment and edits existing comment in different files",
         %{conn: conn, grade: grade, staff: staff} do
      timeout = Config.global(:timeout)

      {:ok, agent} = Agent.start_link(fn -> [] end)

      conn =
        unwrap(conn, fn %{page_id: page_id} ->
          filter = &match?(%{method: :console}, &1)

          callback = fn %{params: %{type: type, text: text}} ->
            if type == "error" do
              Agent.update(agent, fn errors -> [{text, type} | errors] end)
            end
          end

          {:ok, _} =
            EventListener.start_link(
              %{guid: page_id, filter: filter, callback: callback},
              name: :console_listener
            )

          {:ok, _} =
            Page.update_subscription(page_id,
              event: :console,
              enabled: true,
              timeout: timeout
            )
        end)

      conn =
        conn
        |> add_session_cookie([value: %{user_id: staff.id}], @session_options)
        |> visit("/staff/grades/#{grade.id}/edit")
        |> assert_has("h1", text: "Edit Grade")
        |> assert_has("span.badge", text: "Draft")

      conn =
        step(conn, "Click file hello.c in file tree", fn conn ->
          conn
          |> assert_has(".list-group-item", text: "hello.c")
          |> click(".list-group-item", "hello.c")
          |> assert_has(".cm-editor")
        end)

      conn =
        step(conn, "Create new line comment on line 5", fn conn ->
          conn
          |> click(".cm-gutterElement:nth-child(5)")
          |> assert_has(".comment-card")
        end)

      conn =
        step(conn, "Fill new comment points and text", fn conn ->
          conn
          |> type(".comment-card input[type=\"number\"]", "-2.0")
          |> type(
            ".comment-card textarea",
            "Missing error check on return value"
          )
        end)

      conn =
        step(conn, "Save new comment", fn conn ->
          Process.sleep(100)
          conn |> click(".comment-card button.btn-secondary")
        end)

      conn =
        step(conn, "Wait for save confirmation", fn conn ->
          Process.sleep(500)
          conn
        end)

      conn =
        step(conn, "Click file Makefile", fn conn ->
          conn
          |> click(".list-group-item", "Makefile")
          |> assert_has(".cm-editor")
        end)

      conn =
        step(conn, "Edit existing comment", fn conn ->
          conn
          |> type(".comment-card input[type=\"number\"]", "-0.5")
          |> type(".comment-card textarea", "Minor style: add clean target")
        end)

      conn =
        step(conn, "Save edited comment", fn conn ->
          Process.sleep(100)
          conn |> click(".comment-card button.btn-secondary")
        end)

      conn =
        step(conn, "Wait for save confirmation", fn conn ->
          Process.sleep(500)
          conn
        end)

      assert_no_console_errors(agent)

      conn
    end
  end
end

defmodule InkfishWeb.SubControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    %{student: student, assignment: assignment, grade: grade, sub: sub} =
      stock_course()

    conn = login(conn, student)
    {:ok, conn: conn, grade: grade, assignment: assignment, sub: sub}
  end

  describe "new sub" do
    test "renders form", %{conn: conn, assignment: asg} do
      conn = get(conn, ~p"/assignments/#{asg}/subs/new")
      html = html_response(conn, 200)

      assert html =~ "New Sub"

      # The uploaders write into this field by id, and `data-upload-field`
      # points at it. Adding an `id` to `<.form>` would rename it (Phoenix
      # prefixes field ids with the form id) and break every file and git
      # submission, so pin the rendered id.
      assert html =~ ~s(id="sub_upload_id")
      assert html =~ ~s(data-upload-field="sub_upload_id")
    end

    test "no longer asks for a note", %{conn: conn, assignment: asg} do
      conn = get(conn, ~p"/assignments/#{asg}/subs/new")
      html = html_response(conn, 200)

      refute html =~ ~s(name="sub[note]")
    end

    test "offers direct markdown when the assignment allows it", %{
      conn: conn,
      assignment: asg
    } do
      asg =
        Inkfish.Repo.update!(Ecto.Changeset.change(asg, allow_markdown: true))

      conn = get(conn, ~p"/assignments/#{asg}/subs/new")
      html = html_response(conn, 200)

      assert html =~ "data-allow-markdown"
    end

    test "does not offer direct markdown by default", %{
      conn: conn,
      assignment: asg
    } do
      conn = get(conn, ~p"/assignments/#{asg}/subs/new")
      html = html_response(conn, 200)

      refute html =~ "data-allow-markdown"
    end
  end

  describe "create sub" do
    test "redirects to show when data is valid", %{conn: conn, assignment: asg} do
      params = params_with_assocs(:sub, assignment: asg)

      conn =
        post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/subs/#{id}"

      conn = get(conn, ~p"/subs/#{id}")
      assert html_response(conn, 200) =~ "Show Sub"
    end

    test "creates a sub from direct markdown", %{
      conn: conn,
      assignment: asg
    } do
      asg =
        Inkfish.Repo.update!(Ecto.Changeset.change(asg, allow_markdown: true))

      params = %{
        "hours_spent" => "1.5",
        "markdown" => "# My answer\r\n\r\n- one\r\n"
      }

      conn = post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/subs/#{id}"

      sub = Inkfish.Subs.get_sub!(String.to_integer(id))
      assert sub.upload.name == "submission.md"

      path =
        Path.join(
          Inkfish.Uploads.Upload.unpacked_path(sub.upload),
          "submission.md"
        )

      # Line endings are normalized: the grader's line numbers have to match
      # the file the student typed.
      assert File.read!(path) == "# My answer\n\n- one\n"

      conn = get(conn, ~p"/subs/#{sub}/files")
      assert html_response(conn, 200) =~ "submission.md"
    end

    test "ignores direct markdown the assignment does not allow", %{
      conn: conn,
      assignment: asg
    } do
      count_before = Inkfish.Repo.aggregate(Inkfish.Subs.Sub, :count)

      params = %{"hours_spent" => "1.5", "markdown" => "# Sneaky"}

      conn = post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      html = html_response(conn, 200)

      # No upload id either, so the sub is rejected rather than stored, and
      # the disallowed text is not echoed back into the form.
      assert html =~ "New Submission"
      refute html =~ "Sneaky"
      assert Inkfish.Repo.aggregate(Inkfish.Subs.Sub, :count) == count_before
    end

    test "renders a failed text upload as a sub form, not an upload form", %{
      conn: conn,
      assignment: asg
    } do
      import Mimic

      Mimic.copy(Inkfish.Subs)

      asg =
        Inkfish.Repo.update!(Ecto.Changeset.change(asg, allow_markdown: true))

      upload_changeset =
        %Inkfish.Uploads.Upload{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:upload, "could not unpack archive: boom")

      expect(Inkfish.Subs, :create_sub_with_text, fn _attrs, _text, _user_id ->
        {:error, upload_changeset}
      end)

      params = %{"hours_spent" => "2.0", "markdown" => "# Hi"}

      conn = post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      html = html_response(conn, 200)

      # Rendering the upload changeset as-is would post `upload[...]` on the
      # next attempt, dropping hours_spent and the rest of the sub's fields.
      assert html =~ ~s(name="sub[hours_spent]")
      refute html =~ ~s(name="upload[hours_spent]")
      assert html =~ "could not unpack archive: boom"
      # The typed answer is still on the page.
      assert html =~ ~s(data-markdown="# Hi")

      verify!()
    end

    test "says why a blank markdown submission was rejected", %{
      conn: conn,
      assignment: asg
    } do
      asg =
        Inkfish.Repo.update!(
          Ecto.Changeset.change(asg,
            allow_markdown: true,
            allow_upload: false,
            allow_git: false
          )
        )

      params = %{"hours_spent" => "1.0", "markdown" => "   \n  "}

      conn = post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      html = html_response(conn, 200)
      assert html =~ "New Submission"
      assert html =~ "Type your submission before submitting it."
    end

    test "keeps the typed markdown when the sub is rejected", %{
      conn: conn,
      assignment: asg
    } do
      asg =
        Inkfish.Repo.update!(Ecto.Changeset.change(asg, allow_markdown: true))

      # hours_spent is required, so this round-trips through the error path.
      params = %{"hours_spent" => nil, "markdown" => "# Keep me"}

      conn = post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      html = html_response(conn, 200)
      assert html =~ "New Submission"
      assert html =~ ~s(data-markdown="# Keep me")
    end

    test "rejects an oversized markdown submission with a readable error", %{
      conn: conn,
      assignment: asg
    } do
      asg =
        Inkfish.Repo.update!(
          Ecto.Changeset.change(asg,
            allow_markdown: true,
            allow_upload: false,
            allow_git: false
          )
        )

      params = %{
        "hours_spent" => "1.0",
        "markdown" => String.duplicate("a", 1_048_577)
      }

      conn = post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      html = html_response(conn, 200)
      assert html =~ "Your submission is too long"
      assert html =~ "the limit is 1048576 bytes"
    end

    test "renders errors when data is invalid", %{conn: conn, assignment: asg} do
      params = %{}

      conn =
        post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      assert html_response(conn, 200) =~ "New Sub"
    end
  end

  describe "sub note" do
    test "is hidden when the sub has no note", %{conn: conn, sub: sub} do
      {:ok, sub} = Inkfish.Repo.update(Ecto.Changeset.change(sub, note: nil))

      conn = get(conn, ~p"/subs/#{sub}")

      refute html_response(conn, 200) =~ "Student Note"
    end

    test "is shown when the sub has a note", %{conn: conn, sub: sub} do
      {:ok, sub} =
        Inkfish.Repo.update(
          Ecto.Changeset.change(sub, note: "Look at section 2")
        )

      conn = get(conn, ~p"/subs/#{sub}")

      html = html_response(conn, 200)
      assert html =~ "Student Note"
      assert html =~ "Look at section 2"
    end
  end

  describe "show sub with feedback grade" do
    test "grade link visible even before grades released", %{conn: conn} do
      due = Inkfish.LocalTime.in_days(1)
      course = insert(:course)
      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)

      asgn =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          due: due,
          force_show_grades: false
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: asgn,
          name: "Code Review"
        )

      student = insert(:user)

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: asgn,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          confirmed: true,
          score: Decimal.new("8.0")
        )

      insert(:line_comment,
        grade: grade,
        path: "main.c",
        line: 5,
        text: "Good work here"
      )

      conn = login(conn, student)
      conn = get(conn, ~p"/subs/#{sub}")

      html = html_response(conn, 200)

      assert html =~ "Code Review"
      assert html =~ ~p"/grades/#{grade}"
    end
  end
end

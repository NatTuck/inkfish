defmodule InkfishWeb.ReactRenderTest do
  # A smoke test for the JSX runtime. Every gate in this repo can be green while
  # the browser throws `ReferenceError: React is not defined` on mount -- the
  # bundle builds, jest renders with Babel's automatic runtime, and eslint is
  # configured for it too (see issue #150, and PR #149 where it happened). This
  # loads a page whose content is React-rendered and fails if it did not
  # replace the server-rendered placeholder.
  use PhoenixTest.Playwright.Case

  import Inkfish.Factory

  alias Inkfish.Uploads

  @session_options [
    store: :cookie,
    key: "_inkfish_key",
    signing_salt: "D/1gbc4j",
    extra: "SameSite=Lax"
  ]

  setup do
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

    student = insert(:user, email: "react-smoke@test.com")
    reg = insert(:reg, course: course, user: student, is_student: true)

    team = insert(:team, teamset: teamset, active: true)
    insert(:team_member, team: team, reg: reg)

    tarball = Path.join(:code.priv_dir(:inkfish), "test_data/helloc.tar.gz")

    upload_attrs =
      params_with_assocs(:upload, user: student, kind: "sub")
      |> Map.put(:upload, %{path: tarball, filename: "helloc.tar.gz"})

    {:ok, upload} = Uploads.create_upload(upload_attrs)

    sub =
      insert(:sub,
        assignment: assignment,
        reg: reg,
        team: team,
        upload: upload,
        grader: nil
      )

    {:ok, %{sub: sub, student: student}}
  end

  @tag timeout: :timer.seconds(60)
  test "the code viewer renders, so the bundle's JSX runtime works",
       %{conn: conn, sub: sub, student: student} do
    conn
    |> add_session_cookie([value: %{user_id: student.id}], @session_options)
    |> visit("/subs/#{sub.id}/files")
    |> assert_has("h1", text: "View Files")
    # React replaced the template's placeholder with the real viewer...
    |> refute_has(".code-viewer", text: "React code viewer loading")
    # ...and rendered the file tree from `window.code_view_data`.
    |> assert_has(".list-group-item", text: "hello.c")
  end
end

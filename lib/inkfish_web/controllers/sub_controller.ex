defmodule InkfishWeb.SubController do
  use InkfishWeb, :controller

  alias InkfishWeb.Plugs

  plug(
    Plugs.FetchItem,
    [sub: "id"]
    when action not in [:index, :new, :create]
  )

  plug(
    Plugs.FetchItem,
    [assignment: "assignment_id"]
    when action in [:index, :new, :create]
  )

  plug(Plugs.RequireReg)

  plug(
    Plugs.RequireSubmitter
    when action in [:show, :feedback]
  )

  alias InkfishWeb.Plugs.Breadcrumb
  plug(Breadcrumb, {:show, :course})
  plug(Breadcrumb, {:show, :assignment})

  plug(
    Breadcrumb,
    {:show, :sub}
    when action in [:files]
  )

  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Teams
  alias Inkfish.Grades.Grade
  alias Inkfish.GradingTasks

  def new(conn, _params) do
    asg = conn.assigns[:assignment]
    reg = conn.assigns[:current_reg]

    with {:ok, team} <- Teams.get_active_team(asg, reg) do
      %{nonce: nonce, token: token} = upload_token(conn, "sub")

      changeset = Subs.change_sub(%Sub{})

      render(conn, "new.html",
        changeset: changeset,
        team: team,
        nonce: nonce,
        token: token,
        markdown: nil
      )
    else
      _ ->
        conn
        |> put_flash(:error, "You need a team to submit.")
        |> redirect(to: ~p"/assignments/#{asg}")
    end
  end

  def create(conn, %{"sub" => sub_params}) do
    asg = conn.assigns[:assignment]
    reg = conn.assigns[:current_reg]
    user = conn.assigns[:current_user]

    {:ok, team} = Teams.get_active_team(asg, reg)

    {markdown, sub_params} = Map.pop(sub_params, "markdown")
    markdown = markdown_text(asg, markdown)

    sub_params =
      sub_params
      |> Map.put("assignment_id", asg.id)
      |> Map.put("reg_id", reg.id)
      |> Map.put("team_id", team.id)

    result =
      if String.trim(markdown) == "" do
        Subs.create_sub(sub_params)
      else
        Subs.create_sub_with_text(sub_params, markdown, user.id)
      end

    case result do
      {:ok, sub} ->
        try do
          GradingTasks.assign_grading_tasks(sub.assignment_id)
        rescue
          ee -> IO.inspect({:assign_grading, ee})
        end

        conn
        |> put_flash(:info, "Sub created successfully.")
        |> redirect(to: ~p"/subs/#{sub}")

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset =
          changeset
          |> sub_changeset(sub_params)
          |> add_blank_markdown_error(asg, markdown, sub_params)

        %{nonce: nonce, token: token} = upload_token(conn, "sub")

        render(conn, "new.html",
          changeset: changeset,
          team: team,
          nonce: nonce,
          token: token,
          markdown: markdown
        )
    end
  end

  # Direct markdown is a per-assignment option: if the assignment does not
  # offer it, a `sub[markdown]` a client sends is ignored rather than used.
  defp markdown_text(asg, markdown) do
    if asg.allow_markdown and is_binary(markdown) do
      markdown
    else
      ""
    end
  end

  # `create_sub_with_text/3` can fail on the upload rather than on the sub.
  # The form takes its field names from the changeset's data, so rendering an
  # `%Upload{}` changeset would make the next attempt post `upload[...]` and
  # silently drop the sub's own fields -- including hours_spent, which would
  # then fall back to the schema default. Re-anchor the errors on a sub
  # changeset, keeping the params the student sent.
  defp sub_changeset(%Ecto.Changeset{data: %Sub{}} = changeset, _sub_params) do
    changeset
  end

  defp sub_changeset(
         %Ecto.Changeset{errors: errors, action: action},
         sub_params
       ) do
    # `Phoenix.HTML.Form` drops a changeset's errors unless it has an action,
    # so set one: this is the create form.
    base = %{Sub.changeset(%Sub{}, sub_params) | action: action || :insert}

    # The upload is built from the text on the server, so a missing upload_id
    # is not something the student can fix.
    base = %{base | errors: Keyword.delete(base.errors, :upload_id)}

    Enum.reduce(errors, base, fn {field, {message, opts}}, acc ->
      Ecto.Changeset.add_error(acc, field, message, opts)
    end)
  end

  # A markdown-only page does not render the `upload_id` field, so
  # "upload_id can't be blank" would be invisible and unactionable there. Say
  # what is actually wrong, next to the editor. When a file or git mode is also
  # offered, the upload_id error is the right one: it points at a field the
  # student can see.
  defp add_blank_markdown_error(changeset, asg, markdown, sub_params) do
    only_markdown =
      asg.allow_markdown and not (asg.allow_upload or asg.allow_git)

    upload_id = sub_params["upload_id"]
    no_upload = is_nil(upload_id) or upload_id == ""

    if only_markdown and String.trim(markdown) == "" and no_upload do
      changeset
      |> Map.update!(:errors, &Keyword.delete(&1, :upload_id))
      |> Ecto.Changeset.add_error(
        :markdown,
        "Type your submission before submitting it."
      )
    else
      changeset
    end
  end

  def show(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    sub = %{sub | team: Teams.get_team!(sub.team_id)}

    autogrades =
      Subs.get_or_create_script_grades(sub)
      |> Enum.map(fn grade ->
        grade = %{grade | sub: sub}
        log = Grade.get_log(grade)
        {grade, log}
      end)

    token =
      if sub.ag_job do
        Phoenix.Token.sign(conn, "autograde", %{uuid: sub.ag_job.uuid})
      else
        nil
      end

    render(conn, "show.html", sub: sub, autogrades: autogrades, token: token)
  end

  def files(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    sub_data = InkfishWeb.SubJSON.show(%{sub: sub})
    gcol = %{points: 0}

    data =
      Inkfish.Subs.read_sub_data(sub.id)
      |> Map.put(:edit, false)
      |> Map.put(:grade, %{
        confirmed: true,
        line_comments: feedback_comments(sub),
        sub: sub_data,
        grade_column: gcol
      })

    git =
      Inkfish.Uploads.Git.repo_info(
        Inkfish.Uploads.Upload.unpacked_path(sub.upload)
      )

    render(conn, "files.html", fluid_grid: true, sub: sub, data: data, git: git)
  end

  def feedback(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    unpacked = Inkfish.Uploads.Upload.unpacked_path(sub.upload)

    items = Inkfish.Grades.list_feedback_items(sub)

    groups =
      items
      |> Enum.map(fn item ->
        context =
          Inkfish.LineComments.Context.get(
            unpacked,
            item.comment.path,
            item.comment.line
          )

        Map.put(item, :context, context)
      end)
      |> Enum.group_by(fn item -> item.grade.id end)
      |> Enum.map(fn {_grade_id, group_items} ->
        first = hd(group_items)

        %{
          grade: first.grade,
          grade_column: first.grade_column,
          status: first.status,
          items: group_items
        }
      end)
      |> Enum.sort_by(fn group -> {group.grade_column.name, group.grade.id} end)

    render(conn, "feedback.html",
      sub: sub,
      assignment: conn.assigns[:assignment],
      groups: groups,
      item_count: length(items)
    )
  end

  # Comments for the viewer: both draft and confirmed feedback, so
  # students can see comments as soon as they are entered.
  defp feedback_comments(sub) do
    items = Inkfish.Grades.list_feedback_items(sub)

    comments =
      items
      |> Enum.map(& &1.comment)
      |> Inkfish.Repo.preload(:user)

    items
    |> Enum.zip(comments)
    |> Enum.map(fn {item, comment} -> comment_json(item, comment) end)
  end

  defp comment_json(item, comment) do
    %{
      id: comment.id,
      path: comment.path,
      line: comment.line,
      points: comment.points,
      text: comment.text,
      grade_id: comment.grade_id,
      draft: item.status == :draft,
      user: InkfishWeb.UserJSON.data(comment.user)
    }
  end

  def rerun_scripts(conn, %{"id" => _id}) do
    sub = conn.assigns[:sub]

    Inkfish.Subs.autograde!(sub)

    conn
    |> put_flash(:info, "Rerunning all grading scripts for sub")
    |> redirect(to: ~p"/staff/subs/#{sub}")
  end
end

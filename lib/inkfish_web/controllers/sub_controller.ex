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
    when action in [:show]
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
    team = Teams.get_active_team(asg, reg)
    %{nonce: nonce, token: token} = upload_token(conn, "sub")

    if team do
      changeset = Subs.change_sub(%Sub{})

      render(conn, "new.html",
        changeset: changeset,
        team: team,
        nonce: nonce,
        token: token
      )
    else
      conn
      |> put_flash(:error, "You need a team to submit.")
      |> redirect(to: ~p"/assignments/#{asg}")
    end
  end

  def create(conn, %{"sub" => sub_params}) do
    asg = conn.assigns[:assignment]
    reg = conn.assigns[:current_reg]
    team = Teams.get_active_team(asg, reg)

    sub_params =
      sub_params
      |> Map.put("assignment_id", asg.id)
      |> Map.put("reg_id", reg.id)
      |> Map.put("team_id", team.id)

    case Subs.create_sub(sub_params) do
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
        # IO.inspect({:error, changeset})
        nonce = Base.encode16(:crypto.strong_rand_bytes(32))
        token = Phoenix.Token.sign(conn, "upload", %{kind: "sub", nonce: nonce})

        render(conn, "new.html",
          changeset: changeset,
          team: team,
          nonce: nonce,
          token: token
        )
    end
  end

  def show(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    sub = %{sub | team: Teams.get_team!(sub.team_id)}

    autogrades =
      sub.grades
      |> Enum.filter(&(!is_nil(&1.log_uuid)))
      |> Enum.map(fn grade ->
        grade = %{grade | sub: sub}
        log = Grade.get_log(grade)
        IO.inspect({:log, log})
        token = Phoenix.Token.sign(conn, "autograde", %{uuid: grade.log_uuid})
        {grade, token, log}
      end)

    render(conn, "show.html", sub: sub, autogrades: autogrades)
  end

  def files(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    sub_data = InkfishWeb.SubJSON.show(%{sub: sub})
    gcol = %{points: 0}

    data =
      Inkfish.Subs.read_sub_data(sub.id)
      |> Map.put(:edit, false)
      |> Map.put(:grade, %{line_comments: [], sub: sub_data, grade_column: gcol})

    render(conn, "files.html", sub: sub, data: data)
  end

  def rerun_scripts(conn, %{"id" => _id}) do
    sub = conn.assigns[:sub]

    Inkfish.Subs.autograde!(sub)

    conn
    |> put_flash(:info, "Rerunning all grading scripts for sub")
    |> redirect(to: ~p"/staff/subs/#{sub}")
  end
end

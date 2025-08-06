defmodule InkfishWeb.Staff.MeetingController do
  use InkfishWeb, :controller

  alias Inkfish.Meetings
  alias Inkfish.Meetings.Meeting

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem,
       [course: "course_id"]
       when action in [:index, :new, :create]

  plug Plugs.FetchItem,
       [meeting: "id"]
       when action in [:show, :edit, :update, :delete]

  plug Plugs.RequireReg, staff: true

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {"Courses (Staff)", :staff_course, :index}
  plug Breadcrumb, {:show, :staff, :course}

  plug Breadcrumb,
       {"Meetings", :staff_course_meeting, :index, :course}
       when action not in [:index, :new, :create]

  def index(conn, _params) do
    meetings = Meetings.list_meetings()
    render(conn, :index, meetings: meetings)
  end

  def new(conn, _params) do
    course = conn.assigns[:course]

    changeset =
      %Meeting{started_at: LocalTime.now()}
      |> Meetings.change_meeting()

    teamsets = Inkfish.Teams.list_teamsets(course)

    render(conn, :new, changeset: changeset, teamsets: teamsets)
  end

  def create(conn, %{"meeting" => meeting_params}) do
    course = conn.assigns[:course]

    meeting_params =
      meeting_params
      |> Map.put("course_id", course.id)
      |> Map.put("secret_code", Meeting.gen_code())

    case Meetings.create_meeting(meeting_params) do
      {:ok, meeting} ->
        InkfishWeb.AttendanceChannel.poll(meeting.course_id)

        conn
        |> put_flash(:info, "Meeting created successfully.")
        |> redirect(to: ~p"/staff/meetings/#{meeting}")

      {:error, %Ecto.Changeset{} = changeset} ->
        teamsets = Inkfish.Teams.list_teamsets(course)
        render(conn, :new, changeset: changeset, teamsets: teamsets)
    end
  end

  def show(conn, %{"id" => _id}) do
    meeting =
      conn.assigns[:meeting]
      |> Meetings.preload_attendances()

    course = conn.assigns[:course]
    student_regs = Inkfish.Users.list_student_regs_for_course(course)

    render(conn, :show, meeting: meeting, student_regs: student_regs)
  end

  def edit(conn, %{"id" => _id}) do
    meeting = conn.assigns[:meeting]
    course = conn.assigns[:course]

    changeset = Meetings.change_meeting(meeting)
    teamsets = Inkfish.Teams.list_teamsets(course)

    render(conn, :edit,
      meeting: meeting,
      changeset: changeset,
      teamsets: teamsets
    )
  end

  def update(conn, %{"id" => _id, "meeting" => meeting_params}) do
    meeting = conn.assigns[:meeting]
    course = conn.assigns[:course]

    case Meetings.update_meeting(meeting, meeting_params) do
      {:ok, meeting} ->
        InkfishWeb.AttendanceChannel.poll(meeting.course_id)

        conn
        |> put_flash(:info, "Meeting updated successfully.")
        |> redirect(to: ~p"/staff/meetings/#{meeting}")

      {:error, %Ecto.Changeset{} = changeset} ->
        teamsets = Inkfish.Teams.list_teamsets(course)

        render(conn, :edit,
          meeting: meeting,
          changeset: changeset,
          teamsets: teamsets
        )
    end
  end

  def delete(conn, %{"id" => _id}) do
    meeting = conn.assigns[:meeting]
    {:ok, meeting} = Meetings.delete_meeting(meeting)

    InkfishWeb.AttendanceChannel.poll(meeting.course_id)

    conn
    |> put_flash(:info, "Meeting deleted successfully.")
    |> redirect(to: ~p"/staff/courses/#{meeting.course}/meetings")
  end
end

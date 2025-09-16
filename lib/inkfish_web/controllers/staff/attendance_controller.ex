defmodule InkfishWeb.Staff.AttendanceController do
  use InkfishWeb, :controller

  alias Inkfish.Attendances
  alias Inkfish.Attendances.Attendance
  alias Inkfish.Users.Reg
  alias Inkfish.Repo.Cache

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem,
       [meeting: "meeting_id"]
       when action in [:index, :new, :create, :excuse]

  plug Plugs.FetchItem,
       [attendance: "id"]
       when action in [:show, :edit, :update, :delete]

  plug Plugs.RequireReg, staff: true

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {"Courses (Staff)", :staff_course, :index}
  plug Breadcrumb, {:show, :staff, :course}
  plug Breadcrumb, {:show, :staff, :meeting}

  def index(conn, _params) do
    attendances = Attendances.list_attendances()
    render(conn, :index, attendances: attendances)
  end

  def new(conn, _params) do
    changeset = Attendances.change_attendance(%Attendance{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"attendance" => attendance_params}) do
    meeting = conn.assigns[:meeting]

    attendance_params =
      attendance_params
      |> Map.put("meeting_id", meeting.id)

    case Attendances.create_attendance(attendance_params) do
      {:ok, attendance} ->
        conn
        |> put_flash(:info, "Attendance created successfully.")
        |> redirect(to: ~p"/staff/attendances/#{attendance}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => _id}) do
    attendance = conn.assigns[:attendance]
    render(conn, :show, attendance: attendance)
  end

  def edit(conn, %{"id" => _id}) do
    attendance = conn.assigns[:attendance]
    changeset = Attendances.change_attendance(attendance)
    render(conn, :edit, attendance: attendance, changeset: changeset)
  end

  def update(conn, %{"id" => _id, "attendance" => attendance_params}) do
    attendance = conn.assigns[:attendance]

    case Attendances.update_attendance(attendance, attendance_params) do
      {:ok, attendance} ->
        conn
        |> put_flash(:info, "Attendance updated successfully.")
        |> redirect(to: ~p"/staff/attendances/#{attendance}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, attendance: attendance, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => _id}) do
    attendance = conn.assigns[:attendance]
    {:ok, at} = Attendances.delete_attendance(attendance)

    conn
    |> put_flash(:info, "Attendance deleted successfully.")
    |> redirect(to: ~p"/staff/meetings/#{at.meeting}")
  end

  def excuse(conn, %{"meeting_id" => _mid, "reg_id" => reg_id}) do
    meeting = conn.assigns[:meeting]
    {:ok, reg} = Cache.get(Reg, reg_id)

    case Attendances.get_attendance(meeting, reg) do
      %Attendance{} = att ->
        {:ok, _att} =
          Attendances.update_attendance(att, %{"excused" => !att.excused})

        conn
        |> put_flash(:info, "Attendance excuse toggled.")
        |> redirect(to: ~p"/staff/meetings/#{meeting}")

      _no_att ->
        dt = LocalTime.now() |> DateTime.add(365, :day)

        params = %{
          "attended_at" => dt,
          "meeting_id" => meeting.id,
          "reg_id" => reg.id,
          "excused" => true
        }

        {:ok, _att} = Attendances.create_attendance(params)

        conn
        |> put_flash(:info, "Created excused attendance.")
        |> redirect(to: ~p"/staff/meetings/#{meeting}")
    end
  end
end

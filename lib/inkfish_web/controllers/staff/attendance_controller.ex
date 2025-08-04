defmodule InkfishWeb.Staff.AttendanceController do
  use InkfishWeb, :controller

  alias Inkfish.Attendances
  alias Inkfish.Attendances.Attendance

  def index(conn, _params) do
    attendances = Attendances.list_attendances()
    render(conn, :index, attendances: attendances)
  end

  def new(conn, _params) do
    changeset = Attendances.change_attendance(%Attendance{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"attendance" => attendance_params}) do
    case Attendances.create_attendance(attendance_params) do
      {:ok, attendance} ->
        conn
        |> put_flash(:info, "Attendance created successfully.")
        |> redirect(to: ~p"/staff/attendances/#{attendance}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    attendance = Attendances.get_attendance!(id)
    render(conn, :show, attendance: attendance)
  end

  def edit(conn, %{"id" => id}) do
    attendance = Attendances.get_attendance!(id)
    changeset = Attendances.change_attendance(attendance)
    render(conn, :edit, attendance: attendance, changeset: changeset)
  end

  def update(conn, %{"id" => id, "attendance" => attendance_params}) do
    attendance = Attendances.get_attendance!(id)

    case Attendances.update_attendance(attendance, attendance_params) do
      {:ok, attendance} ->
        conn
        |> put_flash(:info, "Attendance updated successfully.")
        |> redirect(to: ~p"/staff/attendances/#{attendance}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, attendance: attendance, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    attendance = Attendances.get_attendance!(id)
    {:ok, at} = Attendances.delete_attendance(attendance)

    conn
    |> put_flash(:info, "Attendance deleted successfully.")
    |> redirect(to: ~p"/staff/meetings/#{at.meeting}")
  end
end

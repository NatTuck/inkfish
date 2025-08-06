defmodule InkfishWeb.AttendanceChannel do
  use InkfishWeb, :channel

  alias Inkfish.Repo.Cache
  alias Inkfish.Courses
  alias Inkfish.Courses.Course
  alias Inkfish.Users
  alias Inkfish.Users.User
  alias Inkfish.Meetings
  alias Inkfish.Attendances

  alias InkfishWeb.MeetingJSON
  alias InkfishWeb.AttendanceJSON

  @impl true
  def join("attendance:" <> course_id, _payload, socket) do
    user_id = socket.assigns[:user_id]

    with {:ok, user} <- Cache.get(User, user_id),
         {:ok, course} <- Cache.get(Course, course_id),
         {:ok, reg} <- Users.find_reg(user, course),
         {:ok, _asg} <- Courses.fetch_attendance_assignment(course) do
      meeting = Meetings.get_current_meeting(course)
      attendance = Attendances.get_attendance(meeting, reg)

      socket =
        socket
        |> assign(:course, course)
        |> assign(:reg, reg)
        |> assign(:meeting, meeting)
        |> assign(:attendance, attendance)

      {:ok, attendance_view(socket), socket}
    else
      {:error, msg} ->
        {:error, %{reason: to_string(msg)}}
    end
  end

  def attendance_view(socket) do
    meeting = socket.assigns[:meeting]
    attendance = socket.assigns[:attendance]
    note = socket.assigns[:note]

    %{
      mode: "connected",
      meeting: MeetingJSON.data(meeting),
      attendance: AttendanceJSON.data(attendance),
      note: note
    }
  end

  def check_code(good, code) do
    good = String.downcase(good)

    code =
      code
      |> String.downcase()
      |> String.trim()

    # Slightly slow code checking.
    Process.sleep(500)

    IO.inspect({:codes, good, code})

    if good == code do
      :ok
    else
      {:error, "Bad code"}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("code", %{"code" => code}, socket) do
    course = socket.assigns[:course]
    reg = socket.assigns[:reg]

    meeting = Meetings.get_current_meeting(course)

    attrs = %{
      "attended_at" => LocalTime.now(),
      "meeting_id" => meeting.id,
      "reg_id" => reg.id
    }

    with :ok <- check_code(meeting.secret_code, code),
         {:ok, attendance} <- Attendances.create_attendance(attrs) do
      socket =
        socket
        |> assign(:meeting, meeting)
        |> assign(:attendance, attendance)

      {:reply, {:ok, attendance_view(socket)}, socket}
    else
      {:error, msg} ->
        {:reply, {:error, msg}, socket}
    end
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (attendance:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end
end

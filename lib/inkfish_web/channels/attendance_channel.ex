defmodule InkfishWeb.AttendanceChannel do
  use InkfishWeb, :channel

  intercept ["state", "team_update"]

  alias Inkfish.Repo.Cache
  alias Inkfish.Courses.Course
  alias Inkfish.Users
  alias Inkfish.Users.User
  alias Inkfish.Meetings
  alias Inkfish.Attendances
  alias Inkfish.Teams
  alias Inkfish.Teams.Teamset

  alias InkfishWeb.AttendanceJSON
  alias InkfishWeb.Staff.RegJSON
  alias InkfishWeb.Staff.AttendanceJSON
  alias InkfishWeb.Staff.TeamsetJSON

  alias Phoenix.PubSub

  def poll(course_id) do
    PubSub.broadcast(Inkfish.PubSub, "attendance:#{course_id}", :poll)
  end

  @impl true
  def handle_out("state", payload, socket) do
    push(socket, "state", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_out("team_update", payload, socket) do
    # Only deliver team membership updates to staff. Student sockets are on the
    # same topic but have no use for (and should not receive) team data.
    if socket.assigns[:reg] && socket.assigns[:reg].is_staff do
      push(socket, "team_update", payload)
    end

    {:noreply, socket}
  end

  @impl true
  def join("attendance:" <> course_id, _payload, socket) do
    user_id = socket.assigns[:user_id]

    with {:ok, user} <- Cache.get(User, user_id),
         {:ok, course} <- Cache.get(Course, course_id),
         {:ok, reg} <- Users.find_reg(user, course),
         :ok <- PubSub.subscribe(Inkfish.PubSub, "attendance:#{course_id}") do
      meeting = Meetings.get_current_meeting(course)
      attendance = Attendances.get_attendance(meeting, reg)

      socket =
        socket
        |> assign(:course, course)
        |> assign(:reg, reg)
        |> assign(:meeting, meeting)
        |> assign(:attendance, attendance)
        |> assign(:note, nil)

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
    course = socket.assigns[:course]

    meeting_data = build_meeting_data(meeting, course)

    %{
      mode: "connected",
      meeting: meeting_data,
      attendance: AttendanceJSON.data(attendance),
      note: note
    }
  end

  # Shared, non-personalized view broadcast to every subscriber on check-in.
  # Individual clients derive their own attendance from the join reply and
  # from their own "code" reply, never from this broadcast.
  def roster_view(socket) do
    meeting = socket.assigns[:meeting]
    course = socket.assigns[:course]

    %{
      mode: "connected",
      meeting: build_meeting_data(meeting, course)
    }
  end

  defp build_meeting_data(nil, _course) do
    nil
  end

  defp build_meeting_data(meeting, course) do
    meeting = Meetings.preload_attendances(meeting)
    regs = Users.list_student_regs_for_course(course)

    attendances =
      for reg <- regs do
        att =
          Enum.find(
            meeting.attendances || [],
            &(&1.reg_id == reg.id)
          )

        [
          RegJSON.data(reg),
          AttendanceJSON.data(att)
        ]
      end

    %{
      started_at: meeting.started_at,
      secret_code: meeting.secret_code,
      attendances: attendances
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

    # IO.inspect({:codes, good, code})

    if good == code do
      :ok
    else
      {:error, "Bad code"}
    end
  end

  @impl true
  def handle_in("team_created", %{"teamset_id" => teamset_id}, socket),
    do: broadcast_teamset(teamset_id, socket)

  @impl true
  def handle_in("team_updated", %{"teamset_id" => teamset_id}, socket),
    do: broadcast_teamset(teamset_id, socket)

  @impl true
  def handle_in("team_deleted", %{"teamset_id" => teamset_id}, socket),
    do: broadcast_teamset(teamset_id, socket)

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

      # Broadcast only the shared roster to all subscribers. The acting
      # student's personal attendance is delivered via the reply below; we
      # must not leak one student's personal state onto every other client.
      broadcast(socket, "state", roster_view(socket))

      {:reply, {:ok, attendance_view(socket)}, socket}
    else
      {:error, msg} ->
        {:reply, {:error, msg}, socket}
    end
  end

  @impl true
  def handle_info(:poll, socket) do
    course = socket.assigns[:course]
    reg = socket.assigns[:reg]
    meeting = Meetings.get_current_meeting(course)
    attendance = Attendances.get_attendance(meeting, reg)

    socket =
      socket
      |> assign(:course, course)
      |> assign(:reg, reg)
      |> assign(:meeting, meeting)
      |> assign(:attendance, attendance)

    push(socket, "state", attendance_view(socket))

    {:noreply, socket}
  end

  # Handle team updates broadcast to all subscribers
  @impl true
  def handle_info({:team_update, data}, socket) do
    push(socket, "team_update", data)
    {:noreply, socket}
  end

  # After a team create/update/delete the acting client has already committed
  # the change via the REST API. We ignore whatever (possibly stale) team data
  # the client echoes and instead reload the authoritative teamset from the DB
  # so every staff subscriber reconciles to the same state.
  defp broadcast_teamset(teamset_id, socket) do
    reg = socket.assigns[:reg]

    if reg && reg.is_staff do
      case Teams.get_teamset(teamset_id) do
        %Teamset{} = teamset ->
          broadcast(socket, "team_update", TeamsetJSON.data(teamset))
          {:reply, :ok, socket}

        nil ->
          {:reply, {:error, %{reason: "Teamset not found"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "Forbidden"}}, socket}
    end
  end
end

defmodule InkfishWeb.AttendanceChannelTest do
  use InkfishWeb.ChannelCase
  import Inkfish.Factory

  setup do
    # Create a course with attendance assignment
    course = insert(:course)

    # Create a teamset for the course
    teamset = insert(:teamset, course: course)

    # Create attendance assignment for the course
    bucket = insert(:bucket, course: course)
    assignment = insert(:assignment, bucket: bucket, teamset: teamset)

    # Update course to reference the attendance assignment
    {:ok, course} =
      Inkfish.Courses.update_course(course, %{
        attendance_assignment_id: assignment.id
      })

    # Create user and registration
    user = insert(:user)
    reg = insert(:reg, user: user, course: course, is_student: true)

    # Create a socket with proper user ID
    socket = socket(InkfishWeb.UserSocket, "user_id", %{user_id: user.id})

    # Join the attendance channel with the course ID
    {:ok, reply, socket} =
      subscribe_and_join(
        socket,
        InkfishWeb.AttendanceChannel,
        "attendance:#{course.id}"
      )

    %{socket: socket, course: course, user: user, reg: reg, join_reply: reply}
  end

  test "join succeeds with valid course ID", %{
    socket: socket,
    course: course,
    join_reply: reply
  } do
    assert socket.assigns[:course].id == course.id
    assert reply.mode == "connected"
  end

  test "code message with valid code creates attendance", %{
    socket: socket,
    course: course
  } do
    # Create a meeting for the course
    _meeting =
      insert(:meeting,
        course: course,
        secret_code: "ABC123",
        started_at: DateTime.utc_now()
      )

    ref = push(socket, "code", %{"code" => "ABC123"})
    assert_reply ref, :ok, reply, 1000
    assert reply.mode == "connected"
  end

  test "code message with invalid code returns error", %{
    socket: socket,
    course: course
  } do
    # Create a meeting for the course so there's a current meeting
    insert(:meeting,
      course: course,
      secret_code: "ABC123",
      started_at: DateTime.utc_now()
    )

    # Wait a bit for the meeting to be recognized as current
    Process.sleep(100)

    ref = push(socket, "code", %{"code" => "INVALID"})
    assert_reply ref, :error, "Bad code", 1000
  end
end

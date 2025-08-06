defmodule InkfishWeb.AttendanceChannelTest do
  use InkfishWeb.ChannelCase
  import Inkfish.Factory

  setup do
    # Create a course and user for the attendance channel
    course = insert(:course)
    user = insert(:user)
    
    # Create a socket with proper user ID
    socket = socket(InkfishWeb.UserSocket, "user_id", %{user_id: user.id})
    
    # Join the attendance channel with the course ID
    {:ok, _, socket} = subscribe_and_join(socket, InkfishWeb.AttendanceChannel, "attendance:#{course.id}")

    %{socket: socket, course: course, user: user}
  end

  test "join succeeds with valid course ID", %{socket: socket, course: course} do
    # The setup already tests successful join
    assert socket.assigns[:course].id == course.id
    assert socket.assigns[:mode] == "connected"
  end

  test "code message with valid code creates attendance", %{socket: socket, course: course} do
    # Create a meeting for the course
    meeting = insert(:meeting, course: course, secret_code: "ABC123")
    
    ref = push(socket, "code", %{"code" => "ABC123"})
    assert_reply ref, :ok, reply
    assert reply.mode == "connected"
    assert reply.meeting.id == meeting.id
  end

  test "code message with invalid code returns error", %{socket: socket} do
    ref = push(socket, "code", %{"code" => "INVALID"})
    assert_reply ref, :error, "Bad code"
  end
end

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

  describe "broadcasts" do
    setup do
      # Create a course with attendance assignment
      course = insert(:course)

      # Create attendance assignment for the course
      bucket = insert(:bucket, course: course)
      assignment = insert(:assignment, bucket: bucket)

      {:ok, course} =
        Inkfish.Courses.update_course(course, %{
          attendance_assignment_id: assignment.id
        })

      # Create meeting
      meeting = insert(:meeting, course: course, secret_code: "MEET123")

      # Create user and registration
      user = insert(:user)
      reg = insert(:reg, user: user, course: course, is_student: true)

      # Create another user for second socket (staff)
      staff_user = insert(:user)

      _staff_reg =
        insert(:reg, user: staff_user, course: course, is_staff: true)

      # Student socket
      student_socket =
        socket(InkfishWeb.UserSocket, "user_id", %{user_id: user.id})

      {:ok, _reply, student_socket} =
        subscribe_and_join(
          student_socket,
          InkfishWeb.AttendanceChannel,
          "attendance:#{course.id}"
        )

      # Staff socket
      staff_socket =
        socket(InkfishWeb.UserSocket, "user_id", %{user_id: staff_user.id})

      {:ok, _reply, staff_socket} =
        subscribe_and_join(
          staff_socket,
          InkfishWeb.AttendanceChannel,
          "attendance:#{course.id}"
        )

      %{
        course: course,
        meeting: meeting,
        user: user,
        reg: reg,
        student_socket: student_socket,
        staff_socket: staff_socket
      }
    end

    test "broadcasts :poll after attendance created", %{
      student_socket: student_socket,
      meeting: _meeting
    } do
      # Push code from student
      ref = push(student_socket, "code", %{"code" => "MEET123"})
      assert_reply ref, :ok, _reply, 1000

      # Staff socket should receive a :poll message (broadcast)
      # This will fail until we implement the broadcast in handle_in
      assert_broadcast "state", %{mode: "connected"}
    end

    test "team_created broadcasts to channel", %{
      staff_socket: staff_socket,
      course: _course
    } do
      team_data = %{
        "id" => 123,
        "name" => "Team 1",
        "active" => true,
        "reg_ids" => [1, 2]
      }

      # Push team_created from staff
      ref = push(staff_socket, "team_created", %{"team" => team_data})
      assert_reply ref, :ok, %{}, 1000

      # Both sockets should receive team_update broadcast
      # This will fail until we implement team_created handler
      assert_broadcast "team_update", %{action: "created", team: _team_data}
    end

    test "team_updated broadcasts to channel", %{
      staff_socket: staff_socket
    } do
      team_data = %{
        "id" => 123,
        "active" => false
      }

      ref = push(staff_socket, "team_updated", %{"team" => team_data})
      assert_reply ref, :ok, %{}, 1000

      # This will fail until we implement team_updated handler
      assert_broadcast "team_update", %{action: "updated", team: _team_data}
    end

    test "team_deleted broadcasts to channel", %{
      staff_socket: staff_socket
    } do
      team_data = %{"id" => 123}

      ref = push(staff_socket, "team_deleted", %{"team" => team_data})
      assert_reply ref, :ok, %{}, 1000

      # This will fail until we implement team_deleted handler
      assert_broadcast "team_update", %{action: "deleted", team: _team_data}
    end
  end
end

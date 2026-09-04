defmodule InkfishWeb.AttendanceChannelTest do
  use InkfishWeb.ChannelCase
  import Inkfish.Factory

  setup do
    course = insert(:course)
    user = insert(:user)
    reg = insert(:reg, user: user, course: course, is_student: true)

    socket = socket(InkfishWeb.UserSocket, "user_id", %{user_id: user.id})

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
      course = insert(:course)
      meeting = insert(:meeting, course: course, secret_code: "MEET123")
      teamset = insert(:teamset, course: course)
      user = insert(:user)
      reg = insert(:reg, user: user, course: course, is_student: true)
      staff_user = insert(:user)

      _staff_reg =
        insert(:reg, user: staff_user, course: course, is_staff: true)

      student_socket =
        socket(InkfishWeb.UserSocket, "user_id", %{user_id: user.id})

      {:ok, _reply, student_socket} =
        subscribe_and_join(
          student_socket,
          InkfishWeb.AttendanceChannel,
          "attendance:#{course.id}"
        )

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
        teamset: teamset,
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
      ref = push(student_socket, "code", %{"code" => "MEET123"})
      assert_reply ref, :ok, _reply, 1000

      assert_broadcast "state", %{mode: "connected"}
    end

    test "student check-in broadcast includes meeting attendances list", %{
      student_socket: student_socket,
      course: _course,
      reg: student_reg
    } do
      ref = push(student_socket, "code", %{"code" => "MEET123"})
      assert_reply ref, :ok, _reply, 1000

      assert_broadcast "state", payload, 1000

      assert payload.mode == "connected"
      assert payload.meeting != nil

      assert is_list(payload.meeting.attendances)

      attendances = payload.meeting.attendances
      assert length(attendances) >= 1

      [reg_data, att_data] = List.first(attendances)
      assert reg_data.id == student_reg.id
      assert att_data != nil
      assert att_data.reg_id == student_reg.id
      assert att_data.status in ["on time", "late", "very late", "too late"]
    end

    test "student check-in broadcast attendances use [reg, att] pair format", %{
      student_socket: student_socket,
      course: _course
    } do
      ref = push(student_socket, "code", %{"code" => "MEET123"})
      assert_reply ref, :ok, _reply, 1000

      assert_broadcast "state", %{meeting: %{attendances: attendances}}, 1000

      for [reg_json, att_json] <- attendances do
        assert is_map(reg_json)
        assert reg_json.id != nil
        assert reg_json.user != nil
        assert reg_json.user.name != nil

        if att_json != nil do
          assert is_map(att_json)
          assert att_json.reg_id != nil
          assert att_json.status != nil
        end
      end
    end

    test "student check-in broadcast does not leak personal attendance", %{
      student_socket: student_socket
    } do
      ref = push(student_socket, "code", %{"code" => "MEET123"})
      assert_reply ref, :ok, _reply, 1000

      assert_broadcast "state", payload, 1000
      # Broadcast carries only the shared roster; the acting student's personal
      # attendance is delivered via the reply, never to the whole topic.
      refute Map.has_key?(payload, :attendance)
      refute Map.has_key?(payload, :note)
      assert payload.mode == "connected"
      assert payload.meeting != nil
      assert is_list(payload.meeting.attendances)
    end

    test "team_created broadcasts to channel", %{
      staff_socket: staff_socket,
      teamset: teamset
    } do
      # Push team_created from staff, identifying the teamset that changed.
      ref = push(staff_socket, "team_created", %{"teamset_id" => teamset.id})
      assert_reply ref, :ok, %{}, 1000

      # The server reloads the teamset and broadcasts authoritative data.
      assert_broadcast "team_update", payload, 1000
      assert payload.id == teamset.id
      assert is_list(payload.teams)
      assert payload.course != nil
    end

    test "team_updated broadcasts to channel", %{
      staff_socket: staff_socket,
      teamset: teamset
    } do
      ref = push(staff_socket, "team_updated", %{"teamset_id" => teamset.id})
      assert_reply ref, :ok, %{}, 1000

      assert_broadcast "team_update", payload, 1000
      assert payload.id == teamset.id
      assert is_list(payload.teams)
    end

    test "team_deleted broadcasts to channel", %{
      staff_socket: staff_socket,
      teamset: teamset
    } do
      ref = push(staff_socket, "team_deleted", %{"teamset_id" => teamset.id})
      assert_reply ref, :ok, %{}, 1000

      assert_broadcast "team_update", payload, 1000
      assert payload.id == teamset.id
      assert is_list(payload.teams)
    end

    test "team update from a non-staff member is rejected", %{
      student_socket: student_socket,
      teamset: teamset
    } do
      ref = push(student_socket, "team_created", %{"teamset_id" => teamset.id})
      assert_reply ref, :error, %{reason: "Forbidden"}, 1000
      refute_broadcast "team_update", _payload
    end
  end
end

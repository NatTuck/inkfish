defmodule InkfishWeb.Staff.SubControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  alias Inkfish.Repo
  alias Inkfish.Subs

  setup %{conn: conn} do
    %{staff: staff, assignment: assignment, sub: sub} = stock_course()
    conn = login(conn, staff)
    {:ok, conn: conn, staff: staff, assignment: assignment, sub: sub}
  end

  describe "show sub" do
    test "shows a sub", %{conn: conn, sub: sub} do
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Show Sub"
    end
  end

  describe "activate sub" do
    test "activates an inactive sub and creates active_sub record", %{
      conn: conn,
      assignment: assignment
    } do
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          active: false,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      refute Repo.get_by(Subs.ActiveSub, sub_id: sub.id)

      conn = post(conn, ~p"/staff/subs/#{sub}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      assert Repo.get_by(Subs.ActiveSub, sub_id: sub.id, reg_id: student_reg.id)

      assert Subs.ActiveSub
             |> Repo.all()
             |> Enum.filter(
               &(&1.assignment_id == assignment.id and
                   &1.reg_id == student_reg.id)
             )
             |> length() == 1
    end

    test "activates requested sub even when another sub with ignore_late_penalty is active",
         %{
           conn: conn,
           assignment: assignment
         } do
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload1 = insert(:upload, user: student)
      upload2 = insert(:upload, user: student)

      old_sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload1,
          ignore_late_penalty: true,
          score: nil
        )

      {:ok, _} = Subs.set_sub_active(old_sub)

      new_sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload2
        )

      refute Repo.get_by(Subs.ActiveSub, sub_id: new_sub.id)

      conn = post(conn, ~p"/staff/subs/#{new_sub}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{new_sub}"

      assert Repo.get_by(Subs.ActiveSub,
               sub_id: new_sub.id,
               reg_id: student_reg.id
             )

      refute Repo.get_by(Subs.ActiveSub,
               sub_id: old_sub.id,
               reg_id: student_reg.id
             )

      active_subs =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == student_reg.id)
        )

      assert length(active_subs) == 1
      assert hd(active_subs).sub_id == new_sub.id
    end

    test "activates requested sub even when another sub with score is active",
         %{
           conn: conn,
           assignment: assignment
         } do
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload1 = insert(:upload, user: student)
      upload2 = insert(:upload, user: student)

      old_sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload1,
          score: Decimal.new("85")
        )

      {:ok, _} = Subs.set_sub_active(old_sub)

      new_sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload2
        )

      refute Repo.get_by(Subs.ActiveSub, sub_id: new_sub.id)

      conn = post(conn, ~p"/staff/subs/#{new_sub}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{new_sub}"

      assert Repo.get_by(Subs.ActiveSub,
               sub_id: new_sub.id,
               reg_id: student_reg.id
             )

      refute Repo.get_by(Subs.ActiveSub,
               sub_id: old_sub.id,
               reg_id: student_reg.id
             )

      active_subs =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == student_reg.id)
        )

      assert length(active_subs) == 1
      assert hd(active_subs).sub_id == new_sub.id
    end

    test "maintains invariant: one active_sub per reg after switching active sub",
         %{
           conn: conn,
           assignment: assignment
         } do
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload1 = insert(:upload, user: student)
      upload2 = insert(:upload, user: student)
      upload3 = insert(:upload, user: student)

      sub1 =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload1
        )

      {:ok, _} = Subs.set_sub_active(sub1)

      sub2 =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload2
        )

      sub3 =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload3
        )

      conn = post(conn, ~p"/staff/subs/#{sub2}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub2}"

      active_subs =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == student_reg.id)
        )

      assert length(active_subs) == 1
      assert hd(active_subs).sub_id == sub2.id

      conn = post(conn, ~p"/staff/subs/#{sub3}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub3}"

      active_subs =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == student_reg.id)
        )

      assert length(active_subs) == 1
      assert hd(active_subs).sub_id == sub3.id

      conn = post(conn, ~p"/staff/subs/#{sub1}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub1}"

      active_subs =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == student_reg.id)
        )

      assert length(active_subs) == 1
      assert hd(active_subs).sub_id == sub1.id
    end

    test "updates active_sub for all team members when team has multiple members",
         %{
           conn: conn,
           assignment: assignment
         } do
      student1 = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      reg1 =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student1.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, reg1)

      student2 = insert(:user)

      reg2_attrs = %{
        user_id: student2.id,
        course_id: course_id,
        is_student: true
      }

      {:ok, reg2} = Inkfish.Users.create_reg(reg2_attrs)
      insert(:team_member, team: team, reg: reg2)

      upload1 = insert(:upload, user: student1)
      upload2 = insert(:upload, user: student1)

      sub1 =
        insert(:sub,
          assignment: assignment,
          reg: reg1,
          team: team,
          upload: upload1
        )

      {:ok, _} = Subs.set_sub_active(sub1)

      sub2 =
        insert(:sub,
          assignment: assignment,
          reg: reg1,
          team: team,
          upload: upload2
        )

      conn = post(conn, ~p"/staff/subs/#{sub2}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub2}"

      assert Repo.get_by(Subs.ActiveSub, sub_id: sub2.id, reg_id: reg1.id)
      assert Repo.get_by(Subs.ActiveSub, sub_id: sub2.id, reg_id: reg2.id)

      refute Repo.get_by(Subs.ActiveSub, sub_id: sub1.id, reg_id: reg1.id)
      refute Repo.get_by(Subs.ActiveSub, sub_id: sub1.id, reg_id: reg2.id)

      reg1_active =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == reg1.id)
        )

      assert length(reg1_active) == 1

      reg2_active =
        Subs.ActiveSub
        |> Repo.all()
        |> Enum.filter(
          &(&1.assignment_id == assignment.id and &1.reg_id == reg2.id)
        )

      assert length(reg2_active) == 1
    end
  end

  describe "toggle late penalty" do
    test "toggles late penalty when toggle_late_penalty action is called on inactive sub",
         %{
           conn: conn,
           assignment: assignment
         } do
      # Create a non-active sub for this specific test
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          active: false,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      # The sub should start as inactive (no active_sub record)
      refute Repo.get_by(Subs.ActiveSub, sub_id: sub.id)

      # Call the toggle_late_penalty action
      conn = post(conn, ~p"/staff/subs/#{sub}/toggle_late_penalty")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check the response after redirect
      conn = get(conn, ~p"/staff/subs/#{sub}")

      # The late penalty should be toggled
      assert html_response(conn, 200) =~
               ~r/<strong>Ignore Late Penalty:<\/strong>\s+true/

      # The sub should still be inactive (toggle_late_penalty and activate are independent)
      assert html_response(conn, 200) =~
               ~r/<strong>Active:<\/strong>\s+false/
    end

    test "toggles late penalty when toggle_late_penalty action is called on active sub",
         %{
           conn: conn,
           sub: sub
         } do
      # The sub should start as active (has active_sub record from stock_course) and ignore_late_penalty as false
      assert Repo.get_by(Subs.ActiveSub, sub_id: sub.id)
      refute sub.ignore_late_penalty

      # Call the toggle_late_penalty action
      conn = post(conn, ~p"/staff/subs/#{sub}/toggle_late_penalty")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check the response after redirect
      conn = get(conn, ~p"/staff/subs/#{sub}")

      # The late penalty should be toggled
      assert html_response(conn, 200) =~
               ~r/<strong>Ignore Late Penalty:<\/strong>\s+true/

      # Call the toggle_late_penalty action again
      conn = post(conn, ~p"/staff/subs/#{sub}/toggle_late_penalty")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check the response after redirect
      conn = get(conn, ~p"/staff/subs/#{sub}")

      # And the late penalty should be toggled back
      assert html_response(conn, 200) =~
               ~r/<strong>Ignore Late Penalty:<\/strong>\s+false/
    end
  end

  describe "update sub" do
    test "updates grader when grader_id is provided", %{
      conn: conn,
      sub: sub,
      staff: staff
    } do
      # Test setting grader ID
      params = %{"grader_id" => "#{staff.id}"}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the grader was set
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Updated sub flags: ##{sub.id}"
    end
  end
end

defmodule InkfishWeb.Plugs.RequireStaffTest do
  use InkfishWeb.ConnCase, async: true
  import Inkfish.Factory
  import Phoenix.ConnTest

  alias InkfishWeb.Plugs.RequireStaff

  describe "call/2 with staff registration" do
    test "assigns current_staff_regs for user with staff role", %{conn: conn} do
      course = insert(:course)
      staff = insert(:user)
      staff_reg = insert(:reg, course: course, user: staff, is_staff: true)

      conn =
        conn
        |> assign(:current_user, staff)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      staff_reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert staff_reg_ids == [staff_reg.id]
      refute conn.halted
    end

    test "assigns current_staff_regs for user with prof role", %{conn: conn} do
      course = insert(:course)
      prof = insert(:user)
      prof_reg = insert(:reg, course: course, user: prof, is_prof: true)

      conn =
        conn
        |> assign(:current_user, prof)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert reg_ids == [prof_reg.id]
      refute conn.halted
    end

    test "assigns multiple staff_regs for user with staff role in multiple courses",
         %{conn: conn} do
      course1 = insert(:course)
      course2 = insert(:course)
      staff = insert(:user)
      staff_reg1 = insert(:reg, course: course1, user: staff, is_staff: true)
      staff_reg2 = insert(:reg, course: course2, user: staff, is_staff: true)

      conn =
        conn
        |> assign(:current_user, staff)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert length(reg_ids) == 2
      assert staff_reg1.id in reg_ids
      assert staff_reg2.id in reg_ids
      refute conn.halted
    end

    test "filters out student regs, only includes staff/prof", %{conn: conn} do
      course1 = insert(:course)
      course2 = insert(:course)
      user = insert(:user)
      student_reg = insert(:reg, course: course1, user: user, is_student: true)
      staff_reg = insert(:reg, course: course2, user: user, is_staff: true)

      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert reg_ids == [staff_reg.id]
      refute student_reg.id in reg_ids
      refute conn.halted
    end

    test "includes reg that has both staff and student roles", %{conn: conn} do
      course = insert(:course)
      user = insert(:user)

      mixed_reg =
        insert(:reg,
          course: course,
          user: user,
          is_staff: true,
          is_student: true
        )

      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert reg_ids == [mixed_reg.id]
      refute conn.halted
    end
  end

  describe "call/2 with admin" do
    test "allows admin even without staff regs", %{conn: conn} do
      admin = insert(:user, is_admin: true)

      conn =
        conn
        |> assign(:current_user, admin)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      assert conn.assigns[:current_staff_regs] == []
      refute conn.halted
    end

    test "allows admin with staff regs", %{conn: conn} do
      course = insert(:course)
      admin = insert(:user, is_admin: true)
      staff_reg = insert(:reg, course: course, user: admin, is_staff: true)

      conn =
        conn
        |> assign(:current_user, admin)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert reg_ids == [staff_reg.id]
      refute conn.halted
    end
  end

  describe "call/2 without staff access" do
    test "halts and redirects for user with only student regs", %{conn: conn} do
      course = insert(:course)
      student = insert(:user)

      _student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_user, student)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Access denied."
    end

    test "halts and redirects for user with no regs", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_user, user)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Access denied."
    end

    test "halts and redirects for nil current_user", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_user, nil)
        |> assign(:client_mode, :browser)
        |> RequireStaff.call([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Please log in."
    end
  end

  describe "call/2 with ajax client_mode" do
    test "returns JSON error for user without staff access", %{conn: conn} do
      student = insert(:user)
      course = insert(:course)

      _student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      conn =
        conn
        |> assign(:current_user, student)
        |> assign(:client_mode, :ajax)
        |> RequireStaff.call([])

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == JSON.encode!(%{error: "Access denied."})
    end

    test "returns JSON error for nil current_user", %{conn: conn} do
      conn =
        conn
        |> assign(:current_user, nil)
        |> assign(:client_mode, :ajax)
        |> RequireStaff.call([])

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == JSON.encode!(%{error: "Please log in."})
    end

    test "succeeds for user with staff access", %{conn: conn} do
      course = insert(:course)
      staff = insert(:user)
      staff_reg = insert(:reg, course: course, user: staff, is_staff: true)

      conn =
        conn
        |> assign(:current_user, staff)
        |> assign(:client_mode, :ajax)
        |> RequireStaff.call([])

      reg_ids = Enum.map(conn.assigns[:current_staff_regs], & &1.id)
      assert reg_ids == [staff_reg.id]
      refute conn.halted
    end
  end
end

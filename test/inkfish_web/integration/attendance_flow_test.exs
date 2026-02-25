defmodule InkfishWeb.AttendanceFlowTest do
  use PhoenixTest.Playwright.Case

  import Inkfish.Factory

  describe "two-session attendance and team flow" do
    test "student submits attendance, staff sees and creates team", %{
      conn: _conn
    } do
      # SETUP: Create course, teamset, meeting, users
      course = insert(:course)

      # Create attendance assignment for course
      bucket = insert(:bucket, course: course)
      assignment = insert(:assignment, bucket: bucket)

      {:ok, course} =
        Inkfish.Courses.update_course(course, %{
          attendance_assignment_id: assignment.id
        })

      # Create teamset
      teamset = insert(:teamset, course: course)

      # Create meeting with secret code
      meeting = insert(:meeting, course: course, secret_code: "TESTCODE")

      # Create staff user
      staff_user = insert(:user, email: "staff@test.com")
      insert(:reg, course: course, user: staff_user, is_staff: true)

      # Create student user
      student_user = insert(:user, email: "student@test.com")

      student_reg =
        insert(:reg, course: course, user: student_user, is_student: true)

      # STAFF SESSION: Open teamset management page
      staff_browser = new_context()

      staff_page =
        staff_browser
        |> visit("/staff/teamsets/#{teamset.id}")
        |> login_as(staff_user)

      # Verify staff page loaded
      assert staff_page |> has_text?("Teamset: #{teamset.name}")

      # Verify "Who's Here" section exists
      assert staff_page |> has_text?("Who's Here?")

      # Initially, student should not be present
      # (might show as missing or empty)

      # STUDENT SESSION: Open attendance page
      student_browser = new_context()

      student_page =
        student_browser
        |> visit("/courses/#{course.id}")
        |> login_as(student_user)

      # STEP 1: Student submits attendance code
      student_page
      |> fill_in("code-input", with: "TESTCODE")
      |> click("I'm Here!")

      # Wait for confirmation
      assert student_page |> has_text?("Present")

      # STEP 2: Staff sees student in "Who's Here" (real-time via channel)
      # This will fail until we implement channel broadcast
      staff_page
      |> assert_text("student@test.com", timeout: 5000)

      # STEP 3: Staff should see student in suggestions (filtered by attendance)
      # This will fail until we implement attendance filtering
      staff_page
      |> assert_text("student@test.com")

      # STEP 4: Staff creates team with student
      # Click Add button to add student to new team
      staff_page
      |> click("Add")

      # Click Create Team button
      staff_page
      |> click("Create Team")

      # STEP 5: Staff verifies team created
      # This will fail until we implement team creation via channel
      staff_page
      |> assert_text("Team #", timeout: 5000)

      # STEP 6: Student sees team assignment (real-time via channel)
      # This will fail until we implement team broadcast to students
      student_page
      |> assert_text("Your team:", timeout: 5000)
    end

    test "two staff browsers see same updates", %{conn: _conn} do
      # SETUP: Create course, teamset, meeting, users
      course = insert(:course)

      # Create attendance assignment
      bucket = insert(:bucket, course: course)
      assignment = insert(:assignment, bucket: bucket)

      {:ok, course} =
        Inkfish.Courses.update_course(course, %{
          attendance_assignment_id: assignment.id
        })

      teamset = insert(:teamset, course: course)

      # Create staff users
      staff1 = insert(:user, email: "staff1@test.com")
      insert(:reg, course: course, user: staff1, is_staff: true)

      staff2 = insert(:user, email: "staff2@test.com")
      insert(:reg, course: course, user: staff2, is_staff: true)

      # STAFF 1 SESSION
      staff1_browser = new_context()

      staff1_page =
        staff1_browser
        |> visit("/staff/teamsets/#{teamset.id}")
        |> login_as(staff1)

      # STAFF 2 SESSION
      staff2_browser = new_context()

      staff2_page =
        staff2_browser
        |> visit("/staff/teamsets/#{teamset.id}")
        |> login_as(staff2)

      # Staff 1 creates team (via AJAX + channel)
      # This will fail until we implement channel integration
      staff1_page
      |> click("Add")
      |> click("Create Team")

      # Staff 2 should see the team created (real-time)
      staff2_page
      |> assert_text("Team #", timeout: 5000)
    end
  end

  # Helper to login user in Playwright session
  defp login_as(page, user) do
    # Navigate to login page and authenticate
    # For now, we'll use the existing session mechanism
    # This is a placeholder - actual implementation depends on auth setup
    page
  end
end

defmodule Inkfish.AgJobs.FuseContainerTest do
  use Inkfish.DataCase, async: false

  alias Inkfish.Uploads
  alias Inkfish.Assignments
  alias Inkfish.Courses
  alias Inkfish.Teams
  alias Inkfish.Users
  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Subs
  alias Inkfish.AgJobs
  alias Inkfish.AgJobs.Autograde
  alias Inkfish.Ittys
  alias Inkfish.LocalTime

  describe "hw10 FUSE tests" do
    setup do
      Application.ensure_all_started(:inkfish)

      student = Inkfish.Users.get_user_by_email!("dave@example.com")

      {:ok, course} =
        Courses.create_course(%{
          name: "Test Course CS4310",
          instructor: "Test Instructor [bob@example.com]",
          sections: "section01",
          start_date: LocalTime.today()
        })

      {:ok, bucket} =
        Courses.create_bucket(%{
          name: "Homework",
          weight: Decimal.new("1.0"),
          course_id: course.id
        })

      {:ok, assignment} =
        Assignments.create_assignment(%{
          name: "HW10",
          desc: "FUSE filesystem homework",
          due: LocalTime.in_days(7),
          weight: Decimal.new("1.0"),
          bucket_id: bucket.id,
          teamset_id: course.solo_teamset_id
        })

      {:ok, student_reg} =
        Users.create_reg(%{
          course_id: course.id,
          user_id: student.id,
          is_student: true
        })

      {:ok, team} =
        Teams.create_team(%{
          teamset_id: course.solo_teamset_id,
          reg_id: student_reg.id,
          active: true
        })

      upload_data = file_upload("test/scripts/data/starter-hw10-cs4310.tar.gz")

      {:ok, sub_upload} =
        Uploads.create_upload(%{
          upload: upload_data,
          kind: "sub",
          user_id: student.id
        })

      {:ok, sub} =
        Subs.create_sub(%{
          assignment_id: assignment.id,
          reg_id: student_reg.id,
          team_id: team.id,
          upload_id: sub_upload.id,
          hours_spent: Decimal.new("2.0"),
          note: "Test submission"
        })

      grade_upload_data =
        file_upload("test/scripts/data/grading-hw10-cs4310.tar.gz")

      {:ok, grade_upload} =
        Uploads.create_upload(%{
          upload: grade_upload_data,
          kind: "grade_column",
          user_id: student.id
        })

      {:ok, _teamset} = Teams.get_active_team(assignment, student_reg)

      %{
        student: student,
        course: course,
        bucket: bucket,
        assignment: assignment,
        student_reg: student_reg,
        team: team,
        sub_upload: sub_upload,
        sub: sub,
        grade_upload: grade_upload
      }
    end

    @tag :docker
    test "autograde hw10 without FUSE - expect 1 pass", context do
      {:ok, grade_column} =
        Grades.create_grade_column(%{
          assignment_id: context.assignment.id,
          name: "HW10 Script",
          kind: "script",
          points: Decimal.new("10.0"),
          base: Decimal.new("0.0"),
          limits:
            "{\"cores\":1,\"megs\":1024,\"seconds\":300,\"allow_fuse\":false}",
          upload_id: context.grade_upload.id
        })

      {:ok, grade} =
        Grades.create_grade(%{
          sub_id: context.sub.id,
          grade_column_id: grade_column.id,
          log_uuid: Inkfish.Text.gen_uuid()
        })

      {:ok, ag_job} = AgJobs.create_ag_job(context.sub)

      job = AgJobs.preload_for_autograde(ag_job)
      Autograde.autograde(job)

      wait_for_completion(ag_job.uuid)

      final_grade = Grades.get_grade!(grade.id)

      assert final_grade.score != nil

      {:ok, {passed, total}} = Inkfish.AgJobs.Tap.score(get_grade_result(grade))

      assert total == 18
      assert passed == 1
    end

    @tag :docker
    test "autograde hw10 with FUSE - expect >1 pass", context do
      {:ok, grade_column} =
        Grades.create_grade_column(%{
          assignment_id: context.assignment.id,
          name: "HW10 Script",
          kind: "script",
          points: Decimal.new("10.0"),
          base: Decimal.new("0.0"),
          limits:
            "{\"cores\":1,\"megs\":1024,\"seconds\":300,\"allow_fuse\":true}",
          upload_id: context.grade_upload.id
        })

      {:ok, grade} =
        Grades.create_grade(%{
          sub_id: context.sub.id,
          grade_column_id: grade_column.id,
          log_uuid: Inkfish.Text.gen_uuid()
        })

      {:ok, ag_job} = AgJobs.create_ag_job(context.sub)

      job = AgJobs.preload_for_autograde(ag_job)
      Autograde.autograde(job)

      wait_for_completion(ag_job.uuid)

      final_grade = Grades.get_grade!(grade.id)

      assert final_grade.score != nil

      {:ok, {passed, total}} = Inkfish.AgJobs.Tap.score(get_grade_result(grade))

      assert total == 18
      assert passed > 1
    end
  end

  defp file_upload(path) do
    project_root = File.cwd!()
    full_path = Path.join(project_root, path)

    %Plug.Upload{
      path: full_path,
      filename: Path.basename(full_path),
      content_type: "application/gzip"
    }
  end

  defp wait_for_completion(uuid, timeout \\ 120_000) do
    start = System.monotonic_time(:millisecond)

    wait_loop(uuid, start, timeout)
  end

  defp wait_loop(uuid, start, timeout) do
    now = System.monotonic_time(:millisecond)

    if now - start > timeout do
      flunk("Autograde job timed out after #{timeout}ms")
    end

    case Ittys.peek(uuid) do
      {:ok, view} ->
        if view.done do
          :ok
        else
          Process.sleep(500)
          wait_loop(uuid, start, timeout)
        end

      {:error, :itty_not_found} ->
        Process.sleep(500)
        wait_loop(uuid, start, timeout)
    end
  end

  defp get_grade_result(grade) do
    grade = Repo.preload(grade, sub: [:upload])
    log = Grade.get_log(grade)
    log["result"] || ""
  end
end

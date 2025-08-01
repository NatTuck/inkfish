defmodule Inkfish.Factory do
  use ExMachina.Ecto, repo: Inkfish.Repo

  alias Inkfish.Users.User
  alias Inkfish.Users.Reg
  alias Inkfish.Courses.Course
  alias Inkfish.Courses.Bucket
  alias Inkfish.JoinReqs.JoinReq
  alias Inkfish.Uploads.Upload
  alias Inkfish.Assignments.Assignment
  alias Inkfish.Teams.Teamset
  alias Inkfish.Teams.Team
  alias Inkfish.Teams.TeamMember
  alias Inkfish.Subs.Sub
  alias Inkfish.Grades.GradeColumn
  alias Inkfish.Grades.Grade
  alias Inkfish.LineComments.LineComment
  alias Inkfish.AgJobs.AgJob
  alias Inkfish.ApiKeys.ApiKey

  def stock_course do
    course_params = %{
      params_for(:course)
      | instructor: "Bob Anderson [bob@example.com]",
        name: "Stock Course",
        sections: "lab03, lab04"
    }

    {:ok, course} = Inkfish.Courses.create_course(course_params)
    bucket = insert(:bucket, course: course)

    asgn =
      insert(
        :assignment,
        teamset: course.solo_teamset,
        teamset_id: course.solo_teamset_id,
        bucket: bucket
      )

    grade_column = insert(:grade_column, kind: "feedback", assignment: asgn)
    staff = Inkfish.Users.get_user_by_email!("carol@example.com")

    staff_reg =
      insert(:reg, course: course, user: staff, is_staff: true, is_grader: true)

    student = Inkfish.Users.get_user_by_email!("dave@example.com")
    student_reg = insert(:reg, course: course, user: student, is_student: true)
    {:ok, team} = Inkfish.Teams.get_active_team(asgn, student_reg)
    sub = insert(:sub, assignment: asgn, reg: student_reg, team: team)

    grade =
      insert(:grade,
        grade_column: grade_column,
        sub: sub,
        score: Decimal.new("25.0")
      )

    %{
      course: course,
      bucket: bucket,
      assignment: asgn,
      grade_column: grade_column,
      student: student,
      student_reg: student_reg,
      staff: staff,
      staff_reg: staff_reg,
      team: team,
      sub: sub,
      grade: grade
    }
  end

  def user_factory do
    login = sequence(:login, &"sam#{&1}")
    pass = "#{login}#{login}abc123"
    hashed_pass = Argon2.hash_pwd_salt(pass)

    %User{
      email: "#{login}@example.com",
      given_name: String.capitalize(login),
      surname: "Smith",
      is_admin: false,
      nickname: "",
      password: pass,
      password_confirmation: pass,
      hashed_password: hashed_pass
    }
  end

  def course_factory do
    %Course{
      footer: "",
      name: sequence(:user_name, &"CS #{&1}"),
      start_date: Date.utc_today(),
      instructor: "Bob Anderson [bob@example.com]",
      sections: ""
    }
  end

  def reg_factory do
    %Reg{
      is_grader: false,
      is_prof: false,
      is_staff: false,
      is_student: true,
      user: build(:user),
      course: build(:course)
    }
  end

  def join_req_factory do
    %JoinReq{
      course: build(:course),
      user: build(:user),
      note: "let me in",
      staff_req: false
    }
  end

  def upload_factory do
    %Upload{
      name: "helloc.tar.gz",
      kind: "assignment_starter",
      user: build(:user),
      size: 9001
    }
  end

  def bucket_factory do
    %Bucket{
      name: "Homework",
      weight: Decimal.new("1.0"),
      course: build(:course)
    }
  end

  def teamset_factory do
    %Teamset{
      name: "Homework Teamset",
      course: build(:course)
    }
  end

  def team_factory do
    %Team{
      active: true,
      teamset: build(:teamset)
    }
  end

  def team_member_factory do
    %TeamMember{
      team: build(:team),
      reg: build(:reg)
    }
  end

  def assignment_factory do
    course = build(:course)

    %Assignment{
      desc: "Do some work.",
      due: Inkfish.LocalTime.in_days(4),
      name: sequence(:as_name, &"HW #{&1}"),
      weight: Decimal.new("1.0"),
      bucket: build(:bucket, course: course),
      teamset: build(:teamset, course: course)
    }
  end

  def sub_factory do
    %Sub{
      active: true,
      hours_spent: Decimal.new("4.5"),
      note: "",
      assignment: build(:assignment),
      reg: build(:reg),
      team: build(:team),
      upload: build(:upload),
      grader: build(:reg)
    }
  end

  def grade_column_factory do
    %GradeColumn{
      kind: "number",
      name: "Number Grade",
      points: Decimal.new("50.0"),
      base: Decimal.new("40.0"),
      assignment: build(:assignment)
    }
  end

  def grade_factory do
    %Grade{
      score: Decimal.new("45.7"),
      sub: build(:sub),
      grade_column: build(:grade_column)
    }
  end

  def line_comment_factory do
    %LineComment{
      line: 10,
      path: "hw03/main.c",
      points: Decimal.new("-5.0"),
      text: "Don't mix tabs and spaces",
      grade: build(:grade),
      user: build(:user)
    }
  end

  def ag_job_factory do
    sub = insert(:sub)
    dupkey = "#{sub.assignment_id}/#{sub.reg_id}"

    %AgJob{
      sub: sub,
      sub_id: sub.id,
      dupkey: dupkey,
      prio: 1
    }
  end

  def api_key_factory do
    key = sequence(:key, &"api-key-#{&1}")

    %ApiKey{
      name: "Some API Key",
      key: key,
      user: build(:user)
    }
  end
end

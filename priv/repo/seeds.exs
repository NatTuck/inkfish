# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Inkfish.Repo.insert!(%Inkfish.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
if Application.fetch_env!(:inkfish, :env) == :prod do
  raise "prod"
end

alias Inkfish.Users.User
alias Inkfish.Users.Reg
alias Inkfish.Courses.Bucket
alias Inkfish.Assignments.Assignment

alias Inkfish.Courses
alias Inkfish.Teams

alias Inkfish.Repo

defmodule Make do
  def user(name, admin \\ false) do
    name = String.downcase(name)
    pass = Argon2.hash_pwd_salt("#{name}#{name}")
    user = %User{
      given_name: String.capitalize(name),
      surname: "Anderson",
      email: "#{name}@example.com",
      is_admin: admin,
      hashed_password: pass,
    }

    Repo.insert!(user)
  end

  def course(name) do
    today = Inkfish.LocalTime.today()
    {:ok, course} = Courses.create_course(%{name: name, start_date: today})
    course
  end

  def reg(user, course, attrs) do
    %Reg{user_id: user.id, course_id: course.id}
    |> Map.merge(Enum.into(attrs, %{}))
    |> Repo.insert!()
  end

  def bucket(course, name, weight) do
    Repo.insert!(%Bucket{course_id: course.id, name: name, weight: weight})
  end

  def assignment(course, bucket, name) do
    ts = Teams.get_solo_teamset!(course)
    as = %Assignment{
      name: name,
      desc: name,
      due: days_from_now(3),
      weight: Decimal.new("1.0"),
      bucket_id: bucket.id,
      teamset_id: ts.id,
    }
    Repo.insert!(as)
  end

  def days_from_now(nn) do
    Inkfish.LocalTime.in_days(nn)
  end
end

_uA = Make.user("alice", true)
uB = Make.user("bob")
uC = Make.user("carol")
uD = Make.user("dave")
uE = Make.user("erin")
uF = Make.user("frank")

c0 = Make.course("Data Science of Art History")
Make.reg(uB, c0, is_prof: true)
Make.reg(uC, c0, is_staff: true, is_grader: true)
Make.reg(uD, c0, is_staff: true, is_grader: true)
Make.reg(uE, c0, is_student: true)
Make.reg(uF, c0, is_student: true)

b0 = Make.bucket(c0, "Homework", Decimal.new("1.0"))
_a0 = Make.assignment(c0, b0, "Homework 1")

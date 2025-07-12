defmodule InkfishWeb.Staff.CourseJSON do
  use InkfishWeb, :json

  alias Inkfish.Courses.Course
  alias InkfishWeb.Staff.RegJSON
  alias InkfishWeb.Staff.BucketJSON

  def index(%{courses: courses}) do
    %{data: for(course <- courses, do: data(course))}
  end

  def show(%{course: nil}), do: %{data: nil}

  def show(%{course: course}) do
    %{data: data(course)}
  end

  def data(nil), do: nil

  def data(%Course{} = course) do
    regs = get_assoc(course, :regs) || []
    buckets = get_assoc(course, :buckets) || []

    %{
      id: course.id,
      name: course.name,
      start_date: course.start_date,
      regs: for(reg <- regs, do: RegJSON.data(reg)),
      buckets: for(bucket <- buckets, do: BucketJSON.data(bucket)),
      sections: Inkfish.Courses.Course.list_sections(course)
    }
  end
end

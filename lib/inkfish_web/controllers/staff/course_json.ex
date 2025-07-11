defmodule InkfishWeb.Staff.CourseJson do
  use InkfishWeb.Json
  alias InkfishWeb.Staff.RegJson
  alias InkfishWeb.Staff.BucketJson

  def show(%{course: nil}), do: nil

  def show(%{course: course}) do
    regs = get_assoc(course, :regs) || []
    buckets = get_assoc(course, :buckets) || []

    %{
      name: course.name,
      start_date: course.start_date,
      regs: RegJson.index(%{regs: regs}),
      buckets: BucketJson.index(%{buckets: buckets}),
      sections: Inkfish.Courses.Course.list_sections(course)
    }
  end
end

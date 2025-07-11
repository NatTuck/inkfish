defmodule InkfishWeb.Staff.CourseJson do
  use InkfishWeb.ViewHelpers

  def show(%{course: course}) do
    regs = get_assoc(course, :regs) || []
    buckets = get_assoc(course, :buckets) || []

    %{
      name: course.name,
      start_date: course.start_date,
      regs: render_many(regs, InkfishWeb.Staff.RegView, "reg.json"),
      buckets: render_many(buckets, InkfishWeb.Staff.BucketView, "bucket.json"),
      sections: Inkfish.Courses.Course.list_sections(course)
    }
  end
end

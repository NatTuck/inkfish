defmodule Inkfish.Repo.CacheTest do
  use Inkfish.DataCase

  alias Inkfish.Repo.Cache
  alias Inkfish.Assignments.Assignment
  alias Inkfish.Courses.Bucket
  alias Inkfish.Courses.Course

  setup do
    {:ok, _pid} = Cache.start_link([])
    on_exit(fn -> Cache.flush() end)

    course = insert(:course)
    bucket = insert(:bucket, course: course)
    assignment = insert(:assignment, bucket: bucket)

    {:ok, course: course, bucket: bucket, assignment: assignment}
  end

  describe "get/2" do
    test "fetches an item with path on cache miss", %{assignment: as} do
      {:ok, fetched} = Cache.get(Assignment, as.id)

      assert fetched.id == as.id
      assert fetched.bucket.id == as.bucket_id
      assert fetched.bucket.course.id == as.bucket.course_id
    end

    test "returns cached item on hit without reloading path", %{assignment: as} do
      {:ok, _fetched} = Cache.get(Assignment, as.id)

      {:ok, cached} = Cache.get(Assignment, as.id)
      assert cached.id == as.id
      assert cached.bucket.id == as.bucket_id
    end

    test "applies standard preloads", %{assignment: as} do
      gcol = insert(:grade_column, assignment: as)

      {:ok, fetched} = Cache.get(Assignment, as.id)
      assert length(fetched.grade_columns) == 1
      assert hd(fetched.grade_columns).id == gcol.id
    end

    test "errors on non-existent item" do
      assert {:error, _msg} = Cache.get(Assignment, Ecto.UUID.generate())
    end
  end

  describe "list/2" do
    test "lists items with filters and path", %{course: course, bucket: bucket} do
      insert(:assignment, bucket: bucket)
      other_bucket = insert(:bucket, course: course)
      insert(:assignment, bucket: other_bucket)

      {:ok, assignments} = Cache.list(Assignment, course_id: course.id)

      assert length(assignments) == 3
      assert Enum.all?(assignments, &(&1.bucket.course.id == course.id))
    end

    test "applies pagination", %{bucket: bucket} do
      Enum.each(1..5, fn _ -> insert(:assignment, bucket: bucket) end)

      {:ok, assignments} = Cache.list(Assignment, limit: 2, offset: 1, bucket_id: bucket.id)
      assert length(assignments) == 2
    end

    test "errors on invalid clause" do
      assert {:error, _msg} = Cache.list(Assignment, invalid_field: 1)
    end
  end

  describe "drop/2 and flush/0" do
    test "drops a single item from cache", %{assignment: as} do
      {:ok, _fetched} = Cache.get(Assignment, as.id)
      :ok = Cache.drop(Assignment, as.id)

      {:ok, reloaded} = Cache.get(Assignment, as.id)
      assert reloaded.id == as.id
    end

    test "flushes all cache" do
      {:ok, course} = Cache.get(Course, insert(:course).id)
      {:ok, bucket} = Cache.get(Bucket, insert(:bucket).id)

      :ok = Cache.flush()

      refute Map.has_key?(Process.get({:gen_server, :state}, %{}), Course)
      refute Map.has_key?(Process.get({:gen_server, :state}, %{}), Bucket)
    end
  end
end

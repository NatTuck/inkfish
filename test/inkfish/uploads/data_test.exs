defmodule Inkfish.Uploads.DataTest do
  use Inkfish.DataCase

  alias Inkfish.Uploads.Data
  alias Inkfish.Uploads.Upload

  defp in_tmp_dir(tag, fun) do
    base =
      Path.join(
        System.tmp_dir!(),
        "inkfish-data-test-#{tag}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)

    try do
      fun.(base)
    after
      File.rm_rf!(base)
    end
  end

  describe "read_tree/1" do
    test "reports symlinks as leaves instead of recursing through them" do
      in_tmp_dir("links", fn base ->
        File.mkdir_p!(Path.join(base, "src"))
        File.write!(Path.join(base, "src/main.c"), "int main(void) {}\n")
        File.ln_s!("..", Path.join(base, "src/back"))
        File.ln_s!(".", Path.join(base, "loop"))

        tree = Data.read_tree(base)
        assert tree.type == "directory"

        loop = Enum.find(tree.nodes, &(&1.key == "loop"))
        assert loop.type == "symlink"
        refute Map.has_key?(loop, :nodes)

        src = Enum.find(tree.nodes, &(&1.key == "src"))
        assert src.type == "directory"

        back = Enum.find(src.nodes, &(&1.key == "src/back"))
        assert back.type == "symlink"

        main = Enum.find(src.nodes, &(&1.key == "src/main.c"))
        assert main.type == "regular"
        assert main.text =~ "int main"
      end)
    end
  end

  describe "compute_index/1" do
    test "lists every path, with line counts only for text-sized text files" do
      in_tmp_dir("index", fn base ->
        File.write!(Path.join(base, "main.c"), "one\ntwo\nthree")
        File.write!(Path.join(base, ".hidden"), "x\n")
        File.write!(Path.join(base, "big.txt"), String.duplicate("y", 40_000))
        File.write!(Path.join(base, "blob.bin"), <<1, 2, 0, 3>>)
        File.mkdir_p!(Path.join(base, "sub"))
        File.write!(Path.join(base, "sub/notes.txt"), "a\n")
        File.ln_s!(".", Path.join(base, "loop"))

        index = Data.compute_index(base)

        assert index.paths ==
                 Enum.sort([
                   ".hidden",
                   "big.txt",
                   "blob.bin",
                   "loop",
                   "main.c",
                   "sub",
                   "sub/notes.txt",
                   "Ω_grading_extra.txt"
                 ])

        assert index.line_counts["main.c"] == 3
        assert index.line_counts["sub/notes.txt"] == 2

        assert index.line_counts["Ω_grading_extra.txt"] ==
                 Data.omega_line_count()

        refute Map.has_key?(index.line_counts, ".hidden")
        refute Map.has_key?(index.line_counts, "big.txt")
        refute Map.has_key?(index.line_counts, "blob.bin")
        refute Map.has_key?(index.line_counts, "loop")
        refute Map.has_key?(index.line_counts, "sub")
      end)
    end

    test "an empty tree still offers the omega grading file" do
      in_tmp_dir("empty", fn base ->
        index = Data.compute_index(base)

        assert index.paths == ["Ω_grading_extra.txt"]

        assert index.line_counts == %{
                 "Ω_grading_extra.txt" => Data.omega_line_count()
               }
      end)
    end

    test "a missing tree has no paths at all" do
      base =
        Path.join(
          System.tmp_dir!(),
          "inkfish-data-test-missing-#{System.unique_integer([:positive])}"
        )

      index = Data.compute_index(base)

      assert index.paths == []
      assert index.line_counts == %{}
    end
  end

  describe "file_index/1" do
    test "computes once, caches on disk, and invalidates" do
      upload = %Upload{id: Ecto.UUID.generate()}
      on_exit(fn -> File.rm_rf!(Upload.upload_dir(upload)) end)

      index = Data.file_index(upload)
      assert index.paths == ["Ω_grading_extra.txt"]
      assert File.exists?(Data.index_path(upload))

      assert Data.file_index(upload) == index

      Data.invalidate_index(upload)
      refute File.exists?(Data.index_path(upload))
    end
  end
end

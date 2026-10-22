defmodule Inkfish.UploadsTest do
  use Inkfish.DataCase
  import Inkfish.Factory
  import Ecto.Query

  alias Inkfish.Repo
  alias Inkfish.Uploads

  describe "uploads" do
    alias Inkfish.Uploads.Upload

    setup do
      base = Upload.upload_base()

      if String.length(base) > 10 && base =~ ~r/test/ do
        File.rm_rf!(base)
      end

      :ok
    end

    def upload_file do
      priv = :code.priv_dir(:inkfish)
      path = Path.join(priv, "test_data/helloc.tar.gz")
      %{path: path, filename: "helloc.tar.gz"}
    end

    def upload_fixture(attrs \\ %{}) do
      attrs =
        if attrs[:upload] do
          params_with_assocs(:upload, attrs)
        else
          params_with_assocs(:upload, attrs)
          |> Map.put(:upload, upload_file())
        end

      {:ok, upload} = Uploads.create_upload(attrs)
      upload
    end

    def assert_uploads_eq(u1, u2) do
      u1 = Map.drop(u1, [:upload, :user])
      u2 = Map.drop(u2, [:upload, :user])
      assert u1 == u2
    end

    test "list_uploads/0 returns all uploads" do
      upload = upload_fixture()
      assert_uploads_eq(hd(Uploads.list_uploads()), upload)
    end

    test "get_upload!/1 returns the upload with given id" do
      upload = upload_fixture()
      assert_uploads_eq(Uploads.get_upload!(upload.id), upload)
    end

    test "create_upload/1 with valid data creates a upload" do
      attrs =
        params_with_assocs(:upload)
        |> Map.put(:upload, upload_file())

      assert {:ok, %Upload{} = upload} = Uploads.create_upload(attrs)
      assert upload.kind == "assignment_starter"
      assert upload.name == "helloc.tar.gz"
    end

    test "create_upload/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Uploads.create_upload(%{})
    end

    test "create_upload/1 rejects zip archives" do
      path =
        Path.join(
          System.tmp_dir!(),
          "inkfish_zip_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(path, "PK\x03\x04 not really a zip")
      on_exit(fn -> File.rm(path) end)

      attrs =
        params_with_assocs(:upload)
        |> Map.put(:upload, %{path: path, filename: "evil.zip"})

      assert {:error, changeset} = Uploads.create_upload(attrs)
      assert "zip archives are not supported" in errors_on(changeset).upload
    end

    test "create_text_upload/4 stores the text as one markdown file" do
      user = insert(:user)

      assert {:ok, %Upload{} = upload} =
               Uploads.create_text_upload(
                 "submission.md",
                 "# Hi\r\n\r\nBody\r\n",
                 "sub",
                 user.id
               )

      assert upload.name == "submission.md"
      assert upload.kind == "sub"
      assert upload.size == byte_size("# Hi\n\nBody\n")

      path = Path.join(Upload.unpacked_path(upload), "submission.md")
      assert File.exists?(path)

      # CRLF is normalized so the grader's line numbers match what the
      # student saw in the editor.
      assert File.read!(path) == "# Hi\n\nBody\n"
    end

    test "delete_upload/1 deletes the upload and its files" do
      upload = upload_fixture()
      dir = Upload.upload_dir(upload)
      assert File.exists?(dir)

      assert {:ok, %Upload{}} = Uploads.delete_upload(upload)
      refute File.exists?(dir)
      assert_raise Ecto.NoResultsError, fn -> Uploads.get_upload!(upload.id) end
    end

    test "change_upload/1 returns a upload changeset" do
      upload = upload_fixture()
      assert %Ecto.Changeset{} = Uploads.change_upload(upload)
    end

    test "create_upload/1 with student user creating 50 unowned sub uploads results in no more than 6 unowned uploads" do
      user = insert(:user)
      attrs = %{kind: "sub", user_id: user.id, upload: upload_file()}

      for _ <- 1..50 do
        {:ok, _upload} = Uploads.create_upload(attrs)
      end

      unowned_count =
        Repo.aggregate(
          from(up in Upload,
            left_join: subs in assoc(up, :subs),
            where:
              up.kind == "sub" and up.user_id == ^user.id and is_nil(subs.id)
          ),
          :count
        )

      assert unowned_count <= 6
    end

    test "create_git_upload/1 with student user creating 50 unowned sub uploads results in no more than 6 unowned uploads" do
      user = insert(:user)

      attrs = %{kind: "sub", user_id: user.id, name: "test.tar.gz", size: 100}

      for _ <- 1..50 do
        {:ok, _upload} = Uploads.create_git_upload(attrs)
      end

      unowned_count =
        Repo.aggregate(
          from(up in Upload,
            left_join: subs in assoc(up, :subs),
            where:
              up.kind == "sub" and up.user_id == ^user.id and is_nil(subs.id)
          ),
          :count
        )

      assert unowned_count <= 6
    end
  end

  describe "validate_file_size/1" do
    alias Inkfish.Uploads.Upload

    test "reports the offending size and the limit" do
      path =
        Path.join(
          System.tmp_dir!(),
          "big_upload_#{System.unique_integer([:positive])}.bin"
        )

      File.write!(path, :binary.copy(<<0>>, 12_000_000))
      on_exit(fn -> File.rm(path) end)

      cset =
        Upload.changeset(%Upload{}, %{
          kind: "assignment_starter",
          user_id: 1,
          upload: %{path: path, filename: "big.bin"}
        })

      assert {:upload,
              {"uploaded file is too big: 11.4 MiB exceeds the 10 MiB limit", _}} =
               List.keyfind(cset.errors, :upload, 0)
    end
  end
end

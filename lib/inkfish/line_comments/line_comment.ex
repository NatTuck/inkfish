defmodule Inkfish.LineComments.LineComment do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "line_comments" do
    field :line, :integer
    field :path, :string
    field :points, :decimal
    field :text, :string, default: ""

    belongs_to :grade, Inkfish.Grades.Grade
    belongs_to :user, Inkfish.Users.User

    timestamps()
  end

  def parent(), do: :grade

  @doc false
  def changeset(
        line_comment,
        attrs,
        valid_paths \\ nil,
        valid_line_counts \\ nil
      ) do
    line_comment
    |> cast(attrs, [:path, :line, :points, :text, :grade_id, :user_id])
    |> validate_required([:path, :line, :points, :grade_id, :user_id])
    |> validate_text()
    |> validate_path(valid_paths)
    |> validate_line_number(valid_line_counts)
  end

  defp validate_path(changeset, nil), do: changeset

  defp validate_path(changeset, valid_paths) do
    path = get_change(changeset, :path)

    if path in valid_paths do
      changeset
    else
      add_error(changeset, :path, "path does not exist in submission")
    end
  end

  defp validate_line_number(changeset, nil), do: changeset

  defp validate_line_number(changeset, valid_line_counts) do
    path = get_field(changeset, :path)
    line = get_field(changeset, :line)

    case Map.get(valid_line_counts, path) do
      nil ->
        changeset

      max_lines ->
        if line > max_lines do
          add_error(
            changeset,
            :line,
            "exceeds file length (max line: #{max_lines})"
          )
        else
          changeset
        end
    end
  end

  defp validate_text(changeset) do
    text = get_field(changeset, :text)

    case text do
      nil ->
        add_error(changeset, :text, "Comment text cannot be empty")

      text when is_binary(text) ->
        trimmed = String.trim(text)

        if trimmed == "" do
          add_error(changeset, :text, "Comment text cannot be empty")
        else
          changeset
        end

      _ ->
        add_error(changeset, :text, "Comment text cannot be empty")
    end
  end

  def to_map(lc) do
    Map.drop(lc, [:__struct__, :__meta__, :grade, :user])
  end
end

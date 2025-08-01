defmodule Inkfish.Grades.Grade do
  use Ecto.Schema
  import Ecto.Changeset

  alias Inkfish.Uploads.Upload

  @timestamps_opts [type: :utc_datetime]

  schema "grades" do
    field(:score, :decimal)
    field(:log_uuid, :string)
    belongs_to(:sub, Inkfish.Subs.Sub)
    belongs_to(:grade_column, Inkfish.Grades.GradeColumn)
    has_many(:line_comments, Inkfish.LineComments.LineComment)

    field(:ag_job, :any, virtual: true)
    field(:started_at, :any, virtual: true)

    timestamps()
  end

  def parent(), do: :sub
  def standard_preloads(), do: [:grade_column]

  @doc false
  def changeset(grade, attrs) do
    grade
    |> cast(attrs, [:grade_column_id, :sub_id, :score, :log_uuid])
    |> validate_required([:grade_column_id, :sub_id])
  end

  def api_changeset(grade, attrs) do
    grade
    |> cast(attrs, [:grade_column_id, :sub_id])
    |> validate_required([:grade_column_id, :sub_id])
  end

  def to_map(grade) do
    grade = Map.drop(grade, [:__struct__, :__meta__, :sub, :grade_column])

    lcs =
      Enum.map(grade.line_comments, fn lc ->
        Inkfish.LineComments.LineComment.to_map(lc)
      end)

    %{grade | line_comments: lcs}
  end

  def log_path(grade) do
    grade.sub.upload
    |> Upload.logs_path()
    |> Path.join("#{grade.log_uuid}.json")
  end

  def put_log(grade, log) do
    log_path(grade)
    |> File.write!(Jason.encode!(log))
  end

  def get_log(grade) do
    if grade.log_uuid do
      case File.read(log_path(grade)) do
        {:ok, json} -> Jason.decode!(json)
        _else -> nil
      end
    else
      nil
    end
  end

  def delete_log(grade) do
    if grade.log_uuid do
      path = log_path(grade)
      File.rm(path)
    end
  end
end

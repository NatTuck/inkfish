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
  def changeset(line_comment, attrs) do
    line_comment
    |> cast(attrs, [:path, :line, :points, :text, :grade_id, :user_id])
    |> validate_required([:path, :line, :points, :grade_id, :user_id])
  end

  def to_map(lc) do
    Map.drop(lc, [:__struct__, :__meta__, :grade, :user])
  end
end

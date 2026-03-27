defmodule Inkfish.LineComments do
  @moduledoc """
  The LineComments context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.LineComments.LineComment
  alias Inkfish.Grades

  @doc """
  Returns the list of line_comments.

  ## Examples

      iex> list_line_comments()
      [%LineComment{}, ...]

  """
  def list_line_comments do
    Repo.all(
      from lc in LineComment,
        preload: [:user]
    )
  end

  def list_line_comments(grade_id) do
    Repo.all(
      from lc in LineComment,
        where: lc.grade_id == ^grade_id,
        preload: [:user]
    )
  end

  @doc """
  Gets a single line_comment.

  Raises `Ecto.NoResultsError` if the Line comment does not exist.

  ## Examples

      iex> get_line_comment!(123)
      %LineComment{}

      iex> get_line_comment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_line_comment!(id) do
    Repo.one!(
      from lc in LineComment,
        where: lc.id == ^id,
        preload: [:user]
    )
  end

  @doc """
  Creates a line_comment.

  ## Examples

      iex> create_line_comment(%{field: value})
      {:ok, %LineComment{}}

      iex> create_line_comment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_line_comment(attrs \\ %{}, valid_paths \\ nil) do
    grade_id = attrs["grade_id"] || attrs[:grade_id]

    valid_paths =
      if valid_paths == :auto do
        lookup_valid_paths(grade_id)
      else
        valid_paths
      end

    lc =
      %LineComment{}
      |> LineComment.changeset(attrs, valid_paths)
      |> Repo.insert()

    case lc do
      {:ok, lc} ->
        {:ok, grade} = Inkfish.Grades.update_feedback_score(lc.grade_id)
        grade = Grades.get_grade!(grade.id)
        lc = Repo.preload(lc, :user)
        {:ok, %{lc | grade: grade}}

      error ->
        error
    end
  end

  defp lookup_valid_paths(grade_id) when is_integer(grade_id) do
    grade = Grades.get_grade!(grade_id)
    sub = Inkfish.Subs.get_sub!(grade.sub_id)
    data = Inkfish.Subs.read_sub_data(sub)
    extract_path_keys(data.files)
  end

  defp lookup_valid_paths(_), do: nil

  defp extract_path_keys(%{nodes: nodes}) do
    extract_path_keys(nodes, [])
  end

  defp extract_path_keys(files) when is_list(files) do
    extract_path_keys(files, [])
  end

  defp extract_path_keys([], acc), do: acc

  defp extract_path_keys([%{key: key, nodes: nodes} | rest], acc) do
    acc = [key | acc]
    acc = extract_path_keys(nodes ++ rest, acc)
    extract_path_keys(rest, acc)
  end

  defp extract_path_keys([%{key: key} | rest], acc) do
    extract_path_keys(rest, [key | acc])
  end

  @doc """
  Updates a line_comment.

  ## Examples

      iex> update_line_comment(line_comment, %{field: new_value})
      {:ok, %LineComment{}}

      iex> update_line_comment(line_comment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_line_comment(%LineComment{} = line_comment, attrs) do
    result =
      line_comment
      |> LineComment.changeset(attrs)
      |> Repo.update()
      |> Repo.Cache.updated()

    case result do
      {:ok, %LineComment{} = lc} ->
        {:ok, grade} = Inkfish.Grades.update_feedback_score(lc.grade_id)
        grade = Grades.get_grade!(grade.id)
        Inkfish.Subs.save_sub_dump!(grade.sub.id)
        lc = Repo.preload(lc, :user)
        {:ok, %{lc | grade: grade}}

      other ->
        other
    end
  end

  @doc """
  Deletes a LineComment.

  ## Examples

      iex> delete_line_comment(line_comment)
      {:ok, %LineComment{}}

      iex> delete_line_comment(line_comment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_line_comment(%LineComment{} = lc) do
    case Repo.delete(lc) do
      {:ok, lc} ->
        :ok = Repo.Cache.drop(lc)
        {:ok, grade} = Inkfish.Grades.update_feedback_score(lc.grade_id)
        Inkfish.Subs.save_sub_dump!(grade.sub.id)
        {:ok, %{lc | grade: grade}}

      other ->
        other
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking line_comment changes.

  ## Examples

      iex> change_line_comment(line_comment)
      %Ecto.Changeset{source: %LineComment{}}

  """
  def change_line_comment(%LineComment{} = line_comment) do
    LineComment.changeset(line_comment, %{})
  end

  def filter_for_display(line_comments, valid_paths) do
    valid_paths = MapSet.new(valid_paths)

    {invalid, valid} =
      Enum.reduce(line_comments, {[], []}, fn lc, {invalid, valid} ->
        if lc.path in valid_paths do
          {invalid, [lc | valid]}
        else
          modified_lc = %{lc | path: "Ω_grading_extra.txt", line: 1}
          {[modified_lc | invalid], valid}
        end
      end)

    {Enum.reverse(invalid), Enum.reverse(valid)}
  end
end

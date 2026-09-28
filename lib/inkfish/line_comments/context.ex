defmodule Inkfish.LineComments.Context do
  @moduledoc """
  Code context for a line comment.

  Reads the commented file out of an unpacked submission and returns a
  few lines of surrounding source, marking the commented line.
  """

  @doc """
  Returns up to two lines of context before and after the commented line.

  Returns a list of `%{line: integer, text: String.t(), is_commented: boolean}`.
  """
  def get(unpacked_path, file_path, line_number) when is_integer(line_number) do
    path = Path.join(unpacked_path, file_path)

    if File.exists?(path) do
      content = File.read!(path)
      lines = String.split(content, "\n")

      # Get +/- 2 lines around the comment
      start_line = max(1, line_number - 2)
      end_line = min(length(lines), line_number + 2)

      lines
      |> Enum.slice(start_line - 1, end_line - start_line + 1)
      |> Enum.with_index(start_line)
      |> Enum.map(fn {text, num} ->
        %{line: num, text: text, is_commented: num == line_number}
      end)
    else
      []
    end
  end

  def get(_unpacked_path, _file_path, _line_number), do: []
end

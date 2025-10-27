defmodule Inkfish.Sandbox do
  @moduledoc """
  Documentation for Sandbox.
  """

  alias Inkfish.Sandbox

  @doc """
  Create a temporary directory with a maximum size.

  returns {:ok, path} or {:error, msg}
  """
  def make_tempfs(max_size) do
    Sandbox.TempFs.make_tempfs(max_size)
  end

  @doc """
  Extract an archive file to a target location.

  Avoids zip bombs and removes unsafe symlinks.
  """
  def extract_archive(path, target, max_size \\ "10M") do
    Sandbox.Archive.safe_extract(path, target, max_size)
  end

  @doc """
  Trigger cleanups for all sandboxed resources.
  """
  def start_cleanups() do
    IO.puts("FIXME: Start sandbox cleanups")
  end
end

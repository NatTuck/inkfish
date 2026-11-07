defmodule Inkfish.Sandbox do
  @moduledoc """
  Documentation for Sandbox.
  """

  require Logger

  alias Inkfish.Sandbox

  @doc """
  Extract an archive file to a target location.

  Avoids zip bombs and removes unsafe symlinks.
  """
  def extract_archive(path, target, max_size \\ "10M") do
    Sandbox.Archive.safe_extract(path, target, max_size)
  end

  @doc """
  Trigger cleanups for all sandboxed resources.

  FIXME: nothing is reaped here yet. `AgJobs.Server` calls this at boot, and it
  used to say so on stdout -- which the test suite's no-output rule does not
  allow. `:debug` keeps the fact discoverable without printing in any
  environment that does not ask for it.
  """
  def start_cleanups() do
    Logger.debug("sandbox cleanups are not implemented yet")
    :ok
  end
end

ExUnit.start(exclude: [:docker, :skip])
Ecto.Adapters.SQL.Sandbox.mode(Inkfish.Repo, :manual)

# `priv/scripts/upload_git_clone.sh` runs the unprivileged `tmptmpfs` helper
# itself, and resolves it through TMPTMPFS_BIN first -- the same precedence as
# `Inkfish.Sandbox.TempFs.bin/0`. The old setuid-root helper is still installed
# at /usr/local/bin/tmptmpfs and would win the PATH lookup, so export the
# configured binary here: tests that run the script directly with `System.cmd`
# inherit this process's OS environment, and `Inkfish.Ittys` merges it into the
# environment it gives the script.
System.put_env("TMPTMPFS_BIN", Inkfish.Sandbox.TempFs.bin())

Application.put_env(:phoenix_test, :base_url, InkfishWeb.Endpoint.url())

{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()

# The Playwright driver handshake is asynchronous: start_link returns while the
# connection is still :pending. Block until it reaches :started so a fast suite
# can't close the port mid-initialization (which makes the node driver die with
# EPIPE).
{:ok, _} =
  PlaywrightEx.Connection.fetch_transport(PlaywrightEx.Supervisor.Connection)

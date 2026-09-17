ExUnit.start(exclude: [:docker, :skip])
Ecto.Adapters.SQL.Sandbox.mode(Inkfish.Repo, :manual)

Application.put_env(:phoenix_test, :base_url, InkfishWeb.Endpoint.url())

{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()

# The Playwright driver handshake is asynchronous: start_link returns while the
# connection is still :pending. Block until it reaches :started so a fast suite
# can't close the port mid-initialization (which makes the node driver die with
# EPIPE).
{:ok, _} =
  PlaywrightEx.Connection.fetch_transport(PlaywrightEx.Supervisor.Connection)

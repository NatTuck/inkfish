ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Inkfish.Repo, :manual)

Application.put_env(:phoenix_test, :base_url, InkfishWeb.Endpoint.url())

{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()

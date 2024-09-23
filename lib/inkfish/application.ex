defmodule Inkfish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Inkfish.Repo,
      # Start the Telemetry supervisor
      InkfishWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Inkfish.PubSub},
      # Singleton
      {Singleton.Supervisor, name: Inkfish.Singleton},
      # 
      # Start the Endpoint (http/https)
      InkfishWeb.Endpoint,
      # Live console output
      Inkfish.Itty.Sup,
    ]


    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Inkfish.Supervisor]
    rv = Supervisor.start_link(children, opts)
    # This needs to come after the supervisor starts.
    {:ok, _} = Inkfish.Itty.Tickets.start()
    rv
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    InkfishWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

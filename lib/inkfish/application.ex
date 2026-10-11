defmodule Inkfish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    check_sandbox_sanitizer()

    base_children = [
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
      Inkfish.Ittys.Sup,

      # Path Cache
      Inkfish.Repo.Cache
    ]

    children =
      if Application.get_env(:inkfish, :env) == :test do
        # Don't start AgJobs server during tests to avoid DB connection issues
        base_children
      else
        base_children ++ [Inkfish.AgJobs.Server]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Inkfish.Supervisor]
    rv = Supervisor.start_link(children, opts)
    rv
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    InkfishWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Uploads and submissions run the symlink sanitizer as a separate OS process
  # through the `elixir` CLI, so that binary has to exist. It is resolved per
  # request, which means a missing one would otherwise only show up as a failed
  # unpack on the first upload; check it once here instead and say plainly what
  # is wrong and how to fix it.
  #
  # Deliberately does not halt the application: grades, attendance and the rest
  # of the app keep working without the sanitizer, and a loud `:error` in the
  # log is a better outcome than refusing to boot. Nothing is logged when the
  # binary resolves. The longer, log-only explanation is used here because this
  # line is aimed at whoever runs the deployment.
  defp check_sandbox_sanitizer do
    case Inkfish.Sandbox.Archive.elixir_bin() do
      {:ok, _path} ->
        :ok

      {:error, _reason} ->
        Logger.error(
          "inkfish sandbox sanitizer check failed: " <>
            Inkfish.Sandbox.Archive.missing_elixir_log_message()
        )
    end
  end
end

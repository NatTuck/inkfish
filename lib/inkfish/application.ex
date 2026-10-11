defmodule Inkfish.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    check_sandbox_sanitizer()
    check_sandbox_unshare()

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
  # through the `elixir` CLI, and the mount namespace both the extraction and
  # the git clone run inside is created by util-linux's `unshare`. Both are
  # resolved per request, which means a missing one would otherwise only show up
  # as a failed unpack or clone on the first upload; check them once here
  # instead and say plainly what is wrong and how to fix it.
  #
  # Resolving `unshare` is not enough for the second one: a host can have the
  # binary and still refuse the user namespace (Ubuntu 23.10+/24.04 restricts it
  # to processes with an AppArmor profile permitting it, and a container's
  # seccomp profile can block `CLONE_NEWUSER`), so the check runs
  # `unshare -Urm -- true` and reports the failure the deployment would actually
  # hit. A probe that only asked whether the binary exists would give an
  # all-clear on exactly the hosts where every upload fails.
  #
  # Deliberately does not halt the application: grades, attendance and the rest
  # of the app keep working without the sandbox, and a loud `:error` in the log
  # is a better outcome than refusing to boot. Nothing is logged when the
  # mechanism works. The longer, log-only explanations are used here because
  # these lines are aimed at whoever runs the deployment.
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

  defp check_sandbox_unshare do
    case Inkfish.Sandbox.TempFs.check_userns() do
      :ok ->
        :ok

      {:error, message} ->
        Logger.error("inkfish sandbox unshare check failed: " <> message)
    end
  end
end

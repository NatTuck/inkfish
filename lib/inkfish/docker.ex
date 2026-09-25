defmodule Inkfish.Docker do
  @moduledoc """
  Minimal Docker Engine API client.

  Replaces the `:docker` hex package (which pulled in the vulnerable `hackney`
  1.x line). Requests are made with `Req`, including over the local Unix socket.

  The host is read from `config :inkfish, :docker` (`:host`), then the
  `DOCKER_HOST` environment variable, defaulting to
  `unix:///var/run/docker.sock`. The API version is read from the same config
  (`:version`), defaulting to `v1.44`.
  """

  @default_host "unix:///var/run/docker.sock"
  @default_version "v1.44"

  @doc """
  Lists all Docker images, including intermediate layers.
  """
  def list_images() do
    get!("/images/json", params: [all: "true"])
  end

  @doc """
  Creates a container from the given config map.
  """
  def create_container(conf) do
    post!("/containers/create", json: conf)
  end

  defp get!(path, opts) do
    client()
    |> Req.get!(Keyword.merge([url: url(path)], opts))
    |> Map.fetch!(:body)
  end

  defp post!(path, opts) do
    client()
    |> Req.post!(Keyword.merge([url: url(path)], opts))
    |> Map.fetch!(:body)
  end

  defp client() do
    config = Application.get_env(:inkfish, :docker, [])

    host =
      config[:host] ||
        System.get_env("DOCKER_HOST", @default_host)

    case host do
      "unix://" <> socket ->
        Req.new(base_url: "http://localhost", unix_socket: socket, retry: false)

      "tcp://" <> addr ->
        Req.new(base_url: "http://" <> addr, retry: false)

      url ->
        Req.new(base_url: url, retry: false)
    end
  end

  defp url(path) do
    "/#{version()}#{path}"
  end

  defp version() do
    Application.get_env(:inkfish, :docker, [])[:version] || @default_version
  end
end

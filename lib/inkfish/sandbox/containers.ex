defmodule Inkfish.Sandbox.Containers do
  def list_sandboxes() do
    args = [
      "ls",
      "--filter",
      "'label=inkfish.sandbox'",
      "--format",
      "'{{json .}}'"
    ]

    {lines, 0} = System.cmd("docker", args, into: [], lines: 4096)

    for line <- lines do
      Jason.decode!(line)
    end
  end

  def get_image_by_tag(tag) do
    Docker.Images.list()
    |> Enum.find(&Enum.member?(&1["RepoTags"], tag))
  end

  def create(conf) do
    conf
    |> Enum.into(%{})
    |> expand_config()
    |> Docker.Containers.create()
    |> just_id()
  end

  defp just_id(resp) do
    if length(resp["Warnings"]) > 0 do
      IO.inspect({:docker_warnings, resp})
    end

    resp["Id"]
  end

  def expand_config(conf) do
    disk = conf[:disk] || 512

    %{
      "Image" => conf.image,
      "Tty" => true,
      "WorkingDir" => "/home/student",
      "Labels" => %{
        "inkfish.sandbox" => "true"
      },
      "HostConfig" => %{
        # Bytes
        "Memory" => megs(conf[:ram] || 1024),
        "MemorySwap" => 2 * megs(conf[:ram] || 1024),
        "NanoCpus" => billion(conf[:cpus] || 1.0),
        "Devices" => conf[:devices] || [],
        "PidsLimit" => 1024,
        "AutoRemove" => true,
        "CapAdd" => conf[:caps] || [],
        "SecurityOpt" => ["apparmor:unconfined"],
        "Tmpfs" => %{
          "/home/student" => "rw,size=#{disk}m,mode=0777",
          "/tmp" => "rw,size=10m,mode=0777"
        },
        "ReadonlyRootFs" => true
      }
    }
  end

  defp megs(xx) do
    round(xx * 1024 * 1024)
  end

  defp billion(xx) do
    round(xx * 1000_000_000.0)
  end
end

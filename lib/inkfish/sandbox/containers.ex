defmodule Inkfish.Sandbox.Containers do
  def get_image_by_tag(tag) do
    Docker.Images.list()
    |> Enum.find(&Enum.member?(&1["RepoTags"], tag))
  end

  def create(conf) do
    conf
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
      "Cmd" => conf.cmd,
      "Env" => conf[:env] || [],
      "WorkingDir" => "/home/student",
      HostConfig => %{
        # Bytes
        Memory => megs(conf[:ram] || 1024),
        MemorySwap => 2 * megs(conf[:ram] || 1024),
        NanoCpus => billion(conf[:cpus] || 1.0),
        Devices => conf[:devices] || [],
        PidsLimit => 1024,
        AutoRemove => true,
        CapAdd => conf[:caps] || [],
        SecurityOpt => ["apparmor:unconfined"],
        TmpFs => %{
          "/var/tmp" => "rw,size=128m",
          "/home/student" => "rw,size=#{disk}m"
        }
      }
    }
  end

  defp megs(xx) do
    xx * 1024 * 1024
  end

  defp billion(xx) do
    xx * 1000_000_000.0
  end
end

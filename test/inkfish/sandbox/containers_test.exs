defmodule Inkfish.Sandbox.ContainersTest do
  use ExUnit.Case, async: true

  alias Inkfish.Sandbox.Containers

  describe "expand_config/1" do
    test "uses megs directly for memory" do
      conf = Containers.expand_config(%{image: "test", megs: 2048})
      expected_memory = 2048 * 1024 * 1024
      assert conf["HostConfig"]["Memory"] == expected_memory
      assert conf["HostConfig"]["MemorySwap"] == 2 * expected_memory
    end

    test "uses default memory when megs not specified" do
      conf = Containers.expand_config(%{image: "test"})
      expected_memory = 1024 * 1024 * 1024
      assert conf["HostConfig"]["Memory"] == expected_memory
    end

    test "adds FUSE device when allow_fuse true" do
      conf = Containers.expand_config(%{image: "test", allow_fuse: true})

      device = %{
        "PathOnHost" => "/dev/fuse",
        "PathInContainer" => "/dev/fuse",
        "CgroupPermissions" => "rwm"
      }

      assert conf["HostConfig"]["Devices"] == [device]
      assert "SYS_ADMIN" in conf["HostConfig"]["CapAdd"]
    end

    test "no FUSE device when allow_fuse false" do
      conf = Containers.expand_config(%{image: "test", allow_fuse: false})
      assert conf["HostConfig"]["Devices"] == []
      assert conf["HostConfig"]["CapAdd"] == []
    end

    test "no FUSE device when allow_fuse not specified" do
      conf = Containers.expand_config(%{image: "test"})
      assert conf["HostConfig"]["Devices"] == []
      assert conf["HostConfig"]["CapAdd"] == []
    end

    test "sets NanoCpus from cpus" do
      conf = Containers.expand_config(%{image: "test", cpus: 2.0})
      assert conf["HostConfig"]["NanoCpus"] == 2_000_000_000
    end

    test "uses cores to set cpus" do
      conf = Containers.expand_config(%{image: "test", cores: 2})
      assert conf["HostConfig"]["NanoCpus"] == 2_000_000_000
    end
  end
end

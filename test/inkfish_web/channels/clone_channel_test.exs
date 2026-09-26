defmodule InkfishWeb.CloneChannelTest do
  use InkfishWeb.ChannelCase

  import Inkfish.GitFixtures

  setup do
    assert System.find_executable("git")
    assert System.find_executable("tmptmpfs")

    base =
      Path.join(
        System.tmp_dir!(),
        "clone_channel_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    user = Inkfish.Users.get_user_by_email!("bob@example.com")
    nonce = Base.encode16(:crypto.strong_rand_bytes(32))

    token =
      Phoenix.Token.sign(InkfishWeb.Endpoint, "upload", %{
        kind: "sub",
        nonce: nonce
      })

    {:ok, _, socket} =
      socket(InkfishWeb.UserSocket, nil, %{user_id: user.id})
      |> subscribe_and_join(
        InkfishWeb.CloneChannel,
        "clone:" <> nonce,
        %{"token" => token}
      )

    {:ok, socket: socket, base: base}
  end

  test "clone clones a git repo", %{socket: socket, base: base} do
    bare =
      make_repo(base, "pancake", fn src ->
        File.write!(Path.join(src, "hello.txt"), "hello, world\n")
      end)

    _ref = push(socket, "clone", %{"url" => "file://#{bare}"})
    assert_push "done", %{status: "normal"}, 30_000
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end

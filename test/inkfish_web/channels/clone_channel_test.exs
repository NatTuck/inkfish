defmodule InkfishWeb.CloneChannelTest do
  use InkfishWeb.ChannelCase

  setup do
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

    {:ok, socket: socket, nonce: nonce, token: token}
  end

  ## FIXME: FIXME FIXME
  @tag :skip
  test "clone clones a git repo", %{socket: socket} do
    pancake = "https://github.com/NatTuck/pancake.git"
    _ref = push(socket, "clone", %{"url" => pancake})
    assert_push "done", %{status: "normal"}, 2_000
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end

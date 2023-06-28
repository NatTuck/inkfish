defmodule InkfishWeb.IttyChannelTest do
  use InkfishWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      InkfishWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(InkfishWeb.TermChannel, "itty:foo")

    %{socket: socket}
  end
end

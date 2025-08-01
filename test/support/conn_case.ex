defmodule InkfishWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use InkfishWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint InkfishWeb.Endpoint

      use InkfishWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import InkfishWeb.ConnCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Inkfish.Repo)

    if !tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Inkfish.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  import Plug.Test
  alias Inkfish.Users.User

  def login(conn, %User{} = user) do
    login(conn, user.email)
  end

  def login(conn, email) do
    user = Inkfish.Users.get_user_by_email!(email)

    conn
    |> init_test_session(%{user_id: user.id})

    # |> assign(:current_user, user)
    # |> assign(:current_user_id, user.id)
  end

  import Inkfish.Factory

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = insert(:user)
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    login(conn, user)
  end
end

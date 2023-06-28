defmodule InkfishWeb.Admin.DockerTagControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.DockerTagsFixtures

  @create_attrs %{dockerfile: "some dockerfile", name: "some name"}
  @update_attrs %{dockerfile: "some updated dockerfile", name: "some updated name"}
  @invalid_attrs %{dockerfile: nil, name: nil}

  describe "index" do
    setup [:login_admin]
    
    test "lists all docker_tags", %{conn: conn} do
      conn = conn
      |> login("alice@example.com")
      |> get(~p"/admin/docker_tags")
      assert html_response(conn, 200) =~ "Listing Docker tags"
    end
  end

  describe "new docker_tag" do
    setup [:login_admin]
    
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/admin/docker_tags/new")
      assert html_response(conn, 200) =~ "New Docker tag"
    end
  end

  describe "create docker_tag" do
    setup [:login_admin]
    
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/admin/docker_tags", docker_tag: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/admin/docker_tags/#{id}"

      conn = get(conn, ~p"/admin/docker_tags/#{id}")
      assert html_response(conn, 200) =~ "Docker tag created"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/admin/docker_tags", docker_tag: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Docker tag"
    end
  end

  describe "edit docker_tag" do
    setup [:create_docker_tag, :login_admin]

    test "renders form for editing chosen docker_tag", %{conn: conn, docker_tag: docker_tag} do
      conn = get(conn, ~p"/admin/docker_tags/#{docker_tag}/edit")
      assert html_response(conn, 200) =~ "Edit Docker tag"
    end
  end

  describe "update docker_tag" do
    setup [:create_docker_tag, :login_admin]

    test "redirects when data is valid", %{conn: conn, docker_tag: docker_tag} do
      conn = put(conn, ~p"/admin/docker_tags/#{docker_tag}", docker_tag: @update_attrs)
      assert redirected_to(conn) == ~p"/admin/docker_tags/#{docker_tag}"

      conn = get(conn, ~p"/admin/docker_tags/#{docker_tag}")
      assert html_response(conn, 200) =~ "some updated dockerfile"
    end

    test "renders errors when data is invalid", %{conn: conn, docker_tag: docker_tag} do
      conn = put(conn, ~p"/admin/docker_tags/#{docker_tag}", docker_tag: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Docker tag"
    end
  end

  describe "delete docker_tag" do
    setup [:create_docker_tag, :login_admin]

    test "deletes chosen docker_tag", %{conn: conn, docker_tag: docker_tag} do
      conn = delete(conn, ~p"/admin/docker_tags/#{docker_tag}")
      assert redirected_to(conn) == ~p"/admin/docker_tags"

      assert_error_sent 404, fn ->
        get(conn, ~p"/admin/docker_tags/#{docker_tag}")
      end
    end
  end

  defp login_admin(%{conn: conn}) do
    conn = conn
    |> login("alice@example.com")
    %{conn: conn}
  end

  defp create_docker_tag(_) do
    docker_tag = docker_tag_fixture()
    %{docker_tag: docker_tag}
  end
end

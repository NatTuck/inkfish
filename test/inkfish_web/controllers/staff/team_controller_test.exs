defmodule InkfishWeb.Staff.TeamControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    course = insert(:course)
    staff = insert(:user)
    _sr = insert(:reg, course: course, user: staff, is_staff: true)
    teamset = insert(:teamset, course: course)
    team = insert(:team, teamset: teamset)
    conn = login(conn, staff)

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"),
     course: course,
     teamset: teamset,
     team: team}
  end

  describe "index" do
    test "lists all teams", %{conn: conn, teamset: ts, team: team} do
      conn = get(conn, ~p"/ajax/staff/teamsets/#{ts}/teams")
      xs = json_response(conn, 200)["data"]
      assert Enum.any?(xs, & &1["active"])
      assert Enum.any?(xs, &(&1["id"] == team.id))
    end
  end

  describe "create team" do
    test "returns team when data is valid", %{
      conn: conn,
      course: course,
      teamset: ts
    } do
      r1 = insert(:reg, course: course)
      r2 = insert(:reg, course: course)

      params =
        params_for(:team, teamset: ts)
        |> Map.put(:reg_ids, [r1.id, r2.id])

      conn =
        post(conn, ~p"/ajax/staff/teamsets/#{ts}/teams",
          team: params
        )

      data = json_response(conn, 201)["data"]
      assert data["teamset"]["id"] == ts.id

      conn = get(conn, ~p"/ajax/staff/teams/#{data["id"]}")
      assert json_response(conn, 200)["data"]["id"] == data["id"]
    end

    test "renders errors when data is invalid", %{conn: conn, teamset: ts} do
      params = %{}

      conn =
        post(conn, ~p"/ajax/staff/teamsets/#{ts}/teams",
          team: params
        )

      assert json_response(conn, 422)["errors"]
    end
  end

  describe "update team" do
    test "redirects when data is valid", %{conn: conn, team: team} do
      params = %{active: false}

      conn =
        put(conn, ~p"/ajax/staff/teams/#{team}",
          team: params
        )

      assert json_response(conn, 200)["data"]["id"] == team.id

      conn = get(conn, ~p"/ajax/staff/teams/#{team}")
      assert json_response(conn, 200)["data"]["id"] == team.id
      assert json_response(conn, 200)["data"]["active"] == false
    end

    test "renders errors when data is invalid", %{conn: conn, team: team} do
      params = %{regs: []}

      conn =
        put(conn, ~p"/ajax/staff/teams/#{team}",
          team: params
        )

      assert json_response(conn, 422)["errors"]
    end
  end

  describe "delete team" do
    test "deletes chosen team", %{conn: conn, team: team} do
      conn = delete(conn, ~p"/ajax/staff/teams/#{team}")
      assert json_response(conn, 200)["data"]["id"] == team.id

      conn = get(conn, ~p"/ajax/staff/teams/#{team}")
      assert json_response(conn, 404)
    end
  end
end

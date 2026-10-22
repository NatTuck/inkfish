defmodule Inkfish.SubsTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Subs
  alias Inkfish.Repo

  describe "subs" do
    alias Inkfish.Subs.Sub

    def sub_fixture(attrs \\ %{}) do
      insert(:sub, attrs)
    end

    test "list_subs/0 returns all subs" do
      sub = sub_fixture()
      assert drop_assocs(Subs.list_subs()) == drop_assocs([sub])
    end

    test "get_sub!/1 returns the sub with given id" do
      sub = sub_fixture()
      assert drop_assocs(Subs.get_sub!(sub.id)) == drop_assocs(sub)
    end

    test "create_sub/1 with valid data creates a sub" do
      # Create a team with members so activation can work
      reg = insert(:reg)
      team = insert(:team)
      insert(:team_member, team: team, reg: reg)

      attrs = params_with_assocs(:sub, reg: reg, team: team)
      assert {:ok, %Sub{} = sub} = Subs.create_sub(attrs)
      assert sub.hours_spent == Decimal.new("4.5")

      # Verify active_sub record was created
      active_sub = Repo.get_by(Subs.ActiveSub, sub_id: sub.id)
      assert active_sub != nil
    end

    test "create_sub_with_text/3 creates a sub whose upload is submission.md" do
      user = insert(:user)
      asg = insert(:assignment)
      reg = insert(:reg)
      team = insert(:team, teamset: asg.teamset)
      insert(:team_member, team: team, reg: reg)

      attrs = %{
        "assignment_id" => asg.id,
        "reg_id" => reg.id,
        "team_id" => team.id,
        "hours_spent" => "2.0"
      }

      assert {:ok, %Sub{} = sub} =
               Subs.create_sub_with_text(attrs, "# Hello\r\n", user.id)

      assert sub.upload.name == "submission.md"

      path =
        Path.join(
          Inkfish.Uploads.Upload.unpacked_path(sub.upload),
          "submission.md"
        )

      assert File.read!(path) == "# Hello\n"
    end

    test "create_sub_with_text/3 deletes the upload when the sub is rejected" do
      user = insert(:user)
      asg = insert(:assignment)
      reg = insert(:reg)
      team = insert(:team, teamset: asg.teamset)
      insert(:team_member, team: team, reg: reg)

      attrs = %{
        "assignment_id" => asg.id,
        "reg_id" => reg.id,
        "team_id" => team.id,
        "hours_spent" => nil
      }

      assert {:error, %Ecto.Changeset{}} =
               Subs.create_sub_with_text(attrs, "# Lost\n", user.id)

      # The upload row is gone, so the 2-day sweep can never find its files:
      # the directory has to go with it.
      assert Inkfish.Uploads.list_uploads() == []
    end

    test "create_sub/1 with invalid data returns error changeset" do
      attrs = Map.put(params_for(:sub), :hours_spent, nil)
      assert {:error, %Ecto.Changeset{}} = Subs.create_sub(attrs)
    end

    test "update_sub_ignore_late/2 updates the sub" do
      sub = sub_fixture()
      attrs = %{"ignore_late_penalty" => true}
      assert %Sub{} = sub = Subs.update_sub_ignore_late(sub, attrs)
      assert sub.ignore_late_penalty == true
    end

    test "update_sub/2 with invalid data returns error changeset" do
      sub = sub_fixture()
      params = %{params_for(:sub) | hours_spent: nil}
      assert {:error, %Ecto.Changeset{}} = Subs.update_sub(sub, params)
      assert drop_assocs(sub) == drop_assocs(Subs.get_sub!(sub.id))
    end

    test "change_sub/1 returns a sub changeset" do
      sub = sub_fixture()
      assert %Ecto.Changeset{} = Subs.change_sub(sub)
    end
  end
end

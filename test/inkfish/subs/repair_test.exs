defmodule Inkfish.Subs.RepairTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Subs
  alias Inkfish.Subs.Repair
  alias Inkfish.Repo

  describe "repair" do
    test "find_orphaned_sub_groups/0 returns groups with no active sub" do
      # Create a sub without an active_sub record (simulating orphaned sub)
      # Need to create team with members for the sub to be activatable
      reg = insert(:reg)
      team = insert(:team)
      insert(:team_member, team: team, reg: reg)
      sub = insert(:sub, reg: reg, team: team)

      orphaned = Repair.find_orphaned_sub_groups()
      assert length(orphaned) == 1
      assert Enum.at(orphaned, 0).assignment_id == sub.assignment_id
      assert Enum.at(orphaned, 0).reg_id == reg.id
    end

    test "find_orphaned_sub_groups/0 excludes groups with active sub" do
      # Create a sub with an active_sub record (normal case)
      reg = insert(:reg)
      team = insert(:team)
      insert(:team_member, team: team, reg: reg)
      sub = insert(:sub, reg: reg, team: team)

      insert(:active_sub,
        reg: sub.reg,
        assignment: sub.assignment,
        sub: sub
      )

      orphaned = Repair.find_orphaned_sub_groups()
      assert orphaned == []
    end

    test "fix_active_subs/0 activates the most recent sub in orphaned groups" do
      # Create an orphaned sub with a team that has members
      reg = insert(:reg)
      team = insert(:team)
      insert(:team_member, team: team, reg: reg)
      sub = insert(:sub, reg: reg, team: team)

      # Verify it's orphaned (1 reg without active_sub)
      assert Repair.count_orphaned_sub_groups() == 1

      # Fix it
      result = Repair.fix_active_subs()
      assert result.total == 1
      assert result.fixed_count == 1
      assert result.failed_count == 0

      # Verify it's no longer orphaned
      assert Repair.count_orphaned_sub_groups() == 0

      # Verify an active_sub record was created for this reg
      active_sub =
        Repo.get_by(Subs.ActiveSub,
          reg_id: reg.id,
          assignment_id: sub.assignment_id
        )

      assert active_sub != nil
      assert active_sub.sub_id == sub.id
    end

    test "fix_active_subs/0 handles multiple orphaned groups" do
      # Create two orphaned subs in different assignments/teams with members
      reg1 = insert(:reg)
      team1 = insert(:team)
      insert(:team_member, team: team1, reg: reg1)
      sub1 = insert(:sub, reg: reg1, team: team1)

      reg2 = insert(:reg)
      team2 = insert(:team)
      insert(:team_member, team: team2, reg: reg2)
      sub2 = insert(:sub, reg: reg2, team: team2)

      # Verify both are orphaned (2 regs without active_subs)
      assert Repair.count_orphaned_sub_groups() == 2

      # Fix them
      result = Repair.fix_active_subs()
      assert result.total == 2
      assert result.fixed_count == 2
      assert result.failed_count == 0

      # Verify none are orphaned
      assert Repair.count_orphaned_sub_groups() == 0

      # Verify active_sub records were created for both regs
      assert Repo.get_by(Subs.ActiveSub,
               reg_id: reg1.id,
               assignment_id: sub1.assignment_id
             ) != nil

      assert Repo.get_by(Subs.ActiveSub,
               reg_id: reg2.id,
               assignment_id: sub2.assignment_id
             ) != nil
    end

    test "fix_active_subs/0 returns 0 when no orphaned groups exist" do
      # Create a sub with an active_sub record (normal case)
      reg = insert(:reg)
      team = insert(:team)
      insert(:team_member, team: team, reg: reg)
      sub = insert(:sub, reg: reg, team: team)

      insert(:active_sub,
        reg: sub.reg,
        assignment: sub.assignment,
        sub: sub
      )

      result = Repair.fix_active_subs()
      assert result.total == 0
      assert result.fixed_count == 0
      assert result.failed_count == 0
    end

    test "fix_active_subs/0 handles multiple subs in same group (activates most recent)" do
      assignment = insert(:assignment)
      reg = insert(:reg)
      team = insert(:team)
      insert(:team_member, team: team, reg: reg)

      # Create older sub (orphaned)
      _old_sub =
        insert(:sub,
          assignment: assignment,
          reg: reg,
          team: team,
          inserted_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

      # Create newer sub (also orphaned)
      new_sub =
        insert(:sub,
          assignment: assignment,
          reg: reg,
          team: team,
          inserted_at: DateTime.utc_now()
        )

      # Verify the group is orphaned (1 reg without active_sub)
      assert Repair.count_orphaned_sub_groups() == 1

      # Fix it
      Repair.fix_active_subs()

      # Verify only the newer sub has an active_sub record for this reg
      active_sub =
        Repo.get_by(Subs.ActiveSub,
          reg_id: reg.id,
          assignment_id: assignment.id
        )

      assert active_sub != nil
      assert active_sub.sub_id == new_sub.id
    end
  end
end

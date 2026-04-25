defmodule Inkfish.Subs.RepairTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Subs
  alias Inkfish.Subs.Repair

  describe "repair" do
    test "find_orphaned_sub_groups/0 returns groups with no active sub" do
      # Create a sub with active: false (simulating orphaned sub)
      sub = insert(:sub, active: false)

      orphaned = Repair.find_orphaned_sub_groups()
      assert length(orphaned) == 1
      assert Enum.at(orphaned, 0).assignment_id == sub.assignment_id
      assert Enum.at(orphaned, 0).team_id == sub.team_id
    end

    test "find_orphaned_sub_groups/0 excludes groups with active sub" do
      # Create a sub with active: true (normal case)
      _sub = insert(:sub, active: true)

      orphaned = Repair.find_orphaned_sub_groups()
      assert orphaned == []
    end

    test "fix_active_subs/0 activates the most recent sub in orphaned groups" do
      # Create an orphaned sub
      sub = insert(:sub, active: false)

      # Verify it's orphaned
      assert Repair.count_orphaned_sub_groups() == 1

      # Fix it
      result = Repair.fix_active_subs()
      assert result.total == 1
      assert result.fixed_count == 1
      assert result.failed_count == 0

      # Verify it's no longer orphaned
      assert Repair.count_orphaned_sub_groups() == 0

      # Verify the sub is now active
      sub_reloaded = Repo.get!(Subs.Sub, sub.id)
      assert sub_reloaded.active == true
    end

    test "fix_active_subs/0 handles multiple orphaned groups" do
      # Create two orphaned subs in different assignments/teams
      sub1 = insert(:sub, active: false)
      sub2 = insert(:sub, active: false)

      # Verify both are orphaned
      assert Repair.count_orphaned_sub_groups() == 2

      # Fix them
      result = Repair.fix_active_subs()
      assert result.total == 2
      assert result.fixed_count == 2
      assert result.failed_count == 0

      # Verify none are orphaned
      assert Repair.count_orphaned_sub_groups() == 0

      # Verify both subs are now active
      sub1_reloaded = Repo.get!(Subs.Sub, sub1.id)
      sub2_reloaded = Repo.get!(Subs.Sub, sub2.id)
      assert sub1_reloaded.active == true
      assert sub2_reloaded.active == true
    end

    test "fix_active_subs/0 returns 0 when no orphaned groups exist" do
      # Create a normal active sub
      _sub = insert(:sub, active: true)

      result = Repair.fix_active_subs()
      assert result.total == 0
      assert result.fixed_count == 0
      assert result.failed_count == 0
    end

    test "fix_active_subs/0 handles multiple subs in same group (activates most recent)" do
      assignment = insert(:assignment)
      team = insert(:team)

      # Create older sub (orphaned)
      old_sub =
        insert(:sub,
          assignment: assignment,
          team: team,
          active: false,
          inserted_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

      # Create newer sub (also orphaned)
      new_sub =
        insert(:sub,
          assignment: assignment,
          team: team,
          active: false,
          inserted_at: DateTime.utc_now()
        )

      # Verify the group is orphaned
      assert Repair.count_orphaned_sub_groups() == 1

      # Fix it
      Repair.fix_active_subs()

      # Verify only the newer sub is active
      old_sub_reloaded = Repo.get!(Subs.Sub, old_sub.id)
      new_sub_reloaded = Repo.get!(Subs.Sub, new_sub.id)
      assert old_sub_reloaded.active == false
      assert new_sub_reloaded.active == true
    end
  end
end

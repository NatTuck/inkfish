defmodule Inkfish.Repo.Migrations.EnsureAllRegsHaveActiveSub do
  use Ecto.Migration

  alias Inkfish.Subs.Repair

  def up do
    # Use the repair module's fix_active_subs function to fix all orphaned groups
    result = Repair.fix_active_subs()

    # Crash if any fixes failed or if there are still orphaned groups
    if result.failed_count > 0 do
      raise "Migration failed: #{result.failed_count} fixes failed. Failed results: #{inspect(Enum.filter(result.results, &(&1.status == :error)))}"
    end

    # Verify no orphaned groups remain
    if result.total == 0 and Repair.count_orphaned_sub_groups() == 0 do
      :ok
    else
      raise "Migration failed: Orphaned groups still exist after fix"
    end
  end

  def down do
    # No-op - we don't want to undo this
    :ok
  end
end

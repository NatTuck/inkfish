defmodule Inkfish.Repo.Migrations.CreateActiveSubs do
  use Ecto.Migration

  def up do
    # Create the active_subs table
    create table(:active_subs) do
      add :reg_id, references(:regs, on_delete: :delete_all), null: false
      add :assignment_id, references(:assignments, on_delete: :delete_all), null: false
      add :sub_id, references(:subs, on_delete: :delete_all), null: false

      timestamps()
    end

    # Unique constraint: one active sub per {reg, assignment}
    create unique_index(:active_subs, [:reg_id, :assignment_id])
    create index(:active_subs, [:sub_id])
    create index(:active_subs, [:assignment_id])

    # Migrate existing active subs
    # For each active sub, create active_sub entries for ALL team members
    # Keep the most recent if there are conflicts (same reg has multiple active subs)
    execute """
    INSERT INTO active_subs (reg_id, assignment_id, sub_id, inserted_at, updated_at)
    SELECT DISTINCT ON (regs.id, subs.assignment_id)
      regs.id,
      subs.assignment_id,
      subs.id,
      NOW(),
      NOW()
    FROM subs
    JOIN teams ON teams.id = subs.team_id
    JOIN team_members ON team_members.team_id = teams.id
    JOIN regs ON regs.id = team_members.reg_id
    WHERE subs.active = true
    ORDER BY regs.id, subs.assignment_id, subs.inserted_at DESC
    ON CONFLICT (reg_id, assignment_id) DO NOTHING
    """

    # Cleanup pass: ensure every reg with subs has an active_sub if possible
    # For any reg without an active_sub but with subs, create one pointing to most recent sub
    execute """
    INSERT INTO active_subs (reg_id, assignment_id, sub_id, inserted_at, updated_at)
    SELECT DISTINCT ON (regs.id, subs.assignment_id)
      regs.id,
      subs.assignment_id,
      subs.id,
      NOW(),
      NOW()
    FROM subs
    JOIN teams ON teams.id = subs.team_id
    JOIN team_members ON team_members.team_id = teams.id
    JOIN regs ON regs.id = team_members.reg_id
    WHERE NOT EXISTS (
      SELECT 1 FROM active_subs
      WHERE active_subs.reg_id = regs.id
      AND active_subs.assignment_id = subs.assignment_id
    )
    ORDER BY regs.id, subs.assignment_id, subs.inserted_at DESC
    ON CONFLICT (reg_id, assignment_id) DO NOTHING
    """
  end

  def down do
    drop table(:active_subs)
  end
end

defmodule Inkfish.Repo.Migrations.CreateApiKey do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add(:key, :string, null: false)
      add(:name, :string, null: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:api_keys, [:user_id]))
  end
end

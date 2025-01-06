defmodule Inkfish.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime

      add :given_name, :string, null: false
      add :surname, :string, null: false
      add :nickname, :string, null: false, default: ""
      add :is_admin, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:users, [:email], unique: true)

    # create table(:users_tokens) do
    #  add :user_id, references(:users, on_delete: :delete_all), null: false
    #  add :token, :binary, null: false
    #  add :context, :string, null: false
    #  add :sent_to, :string
    #  timestamps(updated_at: false)
    # end

    # create index(:users_tokens, [:user_id])
    # create unique_index(:users_tokens, [:context, :token])
  end
end

defmodule AsteriskConnector.Repo.Migrations.CreateUserBindings do
  use Ecto.Migration

  def change do
    create table(:user_bindings) do
      add :phone, :string, null: false
      add :chat_id, :bigint, null: false
      timestamps()
    end
  end
end

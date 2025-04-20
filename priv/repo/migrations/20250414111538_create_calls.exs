defmodule AsteriskConnector.Repo.Migrations.CreateCalls do
  use Ecto.Migration

  def change do
    create table(:calls) do
      add :call_id, :string, null: false
      add :caller, :string, null: false
      add :callee, :string, null: false
      add :status, :string, null: false
      add :duration, :integer
      add :record, :string
      add :start_time, :utc_datetime
      add :redirect_sequence, :integer, null: false
    end
  end
end

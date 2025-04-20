defmodule AsteriskConnector.Schemas.Call do
  use Ecto.Schema
  import Ecto.Changeset

  schema "calls" do
    field :call_id, :string
    field :caller, :string
    field :callee, :string
    field :status, :string
    field :start_time, :utc_datetime
    field :duration, :integer
    field :record, :string
    field :redirect_sequence, :integer
  end

  def changeset(call, attrs \\ %{}) do
    call
    |> cast(attrs, [:call_id, :caller, :callee, :status, :start_time, :duration, :record, :redirect_sequence])
    |> validate_required([:call_id, :caller, :callee, :status, :redirect_sequence])
  end
end

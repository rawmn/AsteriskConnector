defmodule AsteriskConnector.Schemas.UserBinding do
  use Ecto.Schema

  schema "user_bindings" do
    field :phone, :string
    field :chat_id, :integer
    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> Ecto.Changeset.cast(attrs, [:phone, :chat_id])
    |> Ecto.Changeset.validate_required([:phone, :chat_id])
  end
end

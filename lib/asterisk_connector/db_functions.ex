defmodule AsteriskConnector.DbFunctions do
  require Ecto.Query
  alias AsteriskConnector.Schemas.Call, as: Call
  alias AsteriskConnector.Schemas.UserBinding, as: UserBinding
  alias AsteriskConnector.Repo, as: Repo

  def get_chat_id(number) do
    UserBinding
    |> Ecto.Query.where(phone: ^number)
    |> Ecto.Query.first()
    |> Repo.one()
    |> case do
      nil -> nil
      entry -> Map.get(entry, :chat_id)
    end
  end

  def save_chat_id(number, chat_id) do
    UserBinding
    |> Ecto.Query.where(chat_id: ^chat_id)
    |> Ecto.Query.first()
    |> Repo.one()
    |> case do
      nil ->
        %UserBinding{}
        |> UserBinding.changeset(%{
          phone: number,
          chat_id: chat_id
        })
        |> Repo.insert()

      entry ->
        entry
        |> UserBinding.changeset(%{phone: number})
        |> Repo.update()
    end
  end

  def get_missed_calls(callee) do
    case last_answer_time(callee) do
      nil ->
        Call
        |> Ecto.Query.where([call], call.status in ["NOANSWER", "BUSY"])
        |> Ecto.Query.where([call], call.callee == ^callee)
        |> AsteriskConnector.Repo.all()
        |> Enum.map(fn call ->
          %{
            call_id: call.call_id,
            caller: call.caller,
            callee: call.callee,
            status: call.status,
            start_time: call.start_time,
            duration: call.duration
          }
        end)

      last_answer_time ->
        Call
        |> Ecto.Query.where([call], call.status in ["NOANSWER", "BUSY", "CANCEL"])
        |> Ecto.Query.where([call], call.callee == ^callee)
        |> Ecto.Query.where([call], call.start_time > ^last_answer_time)
        |> AsteriskConnector.Repo.all()
        |> Enum.map(fn call ->
          %{
            call_id: call.call_id,
            caller: call.caller,
            callee: call.callee,
            status: call.status,
            start_time: call.start_time,
            duration: call.duration
          }
        end)
    end
  end

  defp last_answer_time(callee) do
    Call
    |> Ecto.Query.where(callee: ^callee)
    |> Ecto.Query.where(status: "ANSWER")
    |> Ecto.Query.order_by(desc: :start_time)
    |> Ecto.Query.limit(1)
    |> AsteriskConnector.Repo.one()
    |> case do
      nil -> nil
      entry -> Map.get(entry, :start_time)
    end
  end

  def redirect_sequence(call_id) do
    case Ecto.Query.where(Call, call_id: ^call_id)
         |> Ecto.Query.last()
         |> Repo.one() do
      nil -> 1
      db_entry -> Map.get(db_entry, :redirect_sequence) + 1
    end
  end

  def insert_db(data) do
    %Call{}
    |> Call.changeset(%{
      call_id: data.call_id,
      caller: data.caller.number,
      callee: data.callee.number,
      status: data.status,
      redirect_sequence: redirect_sequence(data.call_id),
      start_time: data.timestamps.start,
      duration: data.timestamps.duration_call,
      record: data.record_link
    })
    |> Repo.insert()
  end
end

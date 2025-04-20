defmodule AsteriskConnector.TelegramBot do
  require Logger

  def start do
    loop(0)
  end

  defp loop(offset) do
    case Nadia.get_updates(offset: offset, timeout: 30) do
      {:ok, updates} ->
        Enum.each(updates, &process_update/1)

        new_offset =
          if updates != [], do: List.last(updates).update_id + 1, else: offset

        loop(new_offset)

      {:error, reason} ->
        Logger.error(reason)
        loop(offset)
    end
  end

  def send_message(chat_id, {:start_call, details}) do
    Nadia.send_message(
          chat_id,
          "Входящий вызов от [#{details.caller.number}]"
        )
  end

  def send_message(chat_id, {:missed_call, details}) do
    Nadia.send_message(
          chat_id,
          "У вас пропущенный вызов от [#{details.caller.number}]"
        )
  end

  def send_message(chat_id, {:transfer_call, details}) do
    Nadia.send_message(
          chat_id,
          "Перевод вызова на вас:\n[#{details["transfereechannel"]}] ---> [#{details["extension"]}]"
        )
  end

  defp process_update(%{message: %{text: text, chat: %{id: chat_id}}}) do
    Logger.info("[TelegramBot] Получено сообщение: #{text}")

    case text do
      "/start" ->
        Nadia.send_message(
          chat_id,
          "Привет! Я бот для работы с коннектором к Asterisk.\nДля работы укажи номер для которого тебе присылать уведомления с помощью команды /bind <Номер>"
        )

      "/bind " <> number ->
        case AsteriskConnector.DbFunctions.save_chat_id(number, chat_id) do
          {:ok, _} ->
            Logger.debug("Database: Insertion completed")
            Nadia.send_message(
              chat_id,
              "Номер успешно привязан. Теперь вы будете получать уведомления связанные с номером #{number}"
            )

          {_, error} ->
            Logger.error("Database: Insertion error: #{inspect(error.errors)}")
        end

      _ ->
        nil
    end
  end

  defp process_update(_), do: nil
end

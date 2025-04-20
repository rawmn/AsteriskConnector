defmodule AsteriskConnector.Helper do
  require Logger

  def parse_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, _} ->
        case Jason.decode(body) do
          {:ok, params} -> {:ok, params}
          _ -> {:error, "Invalid JSON format"}
        end

      _ ->
        {:error, "Invalid request body"}
    end
  end

  def get_required_param(params, key) do
    case Map.get(params, key) do
      nil -> {:error, "Missing required parameter: #{key}"}
      value -> {:ok, value}
    end
  end

  def originate_call(caller, callee, caller_name) do
    action =
      ElixirAmi.Action.new("Originate", %{
        channel: "PJSIP/#{caller}",
        context: Application.get_env(:asterisk_connector, :context, "org_all"),
        priority: Application.get_env(:asterisk_connector, :priority, "1"),
        exten: callee,
        callerid: caller_name,
        timeout: 30000
      })

    connection = Keyword.get(Application.get_env(:asterisk_connector, :ami), :name)

    case ElixirAmi.Connection.ready?(connection) do
      true ->
        case ElixirAmi.Connection.send_action(connection, action) do
          %ElixirAmi.Response{success: true, keys: %{"message" => message}} ->
            Logger.info("#{message}\nCall originated: #{caller} -> #{callee}")
            {:ok, message}

          %ElixirAmi.Response{keys: %{"message" => message}} ->
            Logger.error("AMI error: #{message}")
            {:error, "AMI error: #{message}"}

          error ->
            Logger.error("Unexpected AMI response: #{inspect(error)}")
            {:error, "Unexpected AMI Response"}
        end

      _ ->
        Logger.error("AMI connection not established")
        {:error, "AMI connection error"}
    end
  end

  def redirect_call(channel, exten, extra_channel, extra_exten) do
    action =
      ElixirAmi.Action.new("Redirect", %{
        channel: channel,
        exten: exten,
        context: Application.get_env(:asterisk_connector, :context),
        priority: Application.get_env(:asterisk_connector, :priority),
        extrachannel: extra_channel,
        extraexten: extra_exten,
        extracontext: Application.get_env(:asterisk_connector, :context),
        extrapriority: Application.get_env(:asterisk_connector, :priority)
      })

    connection = Keyword.get(Application.get_env(:asterisk_connector, :ami), :name)

    case ElixirAmi.Connection.ready?(connection) do
      true ->
        case ElixirAmi.Connection.send_action(connection, action) do
          %ElixirAmi.Response{success: true, keys: %{"message" => message}} ->
            Logger.info("#{message}\nCall redirected: #{channel} -> #{exten}")
            {:ok, message}

          %ElixirAmi.Response{keys: %{"message" => message}} ->
            Logger.error("AMI error: #{message}")
            {:error, "AMI error: #{message}"}

          error ->
            Logger.error("Unexpected AMI response: #{inspect(error)}")
            {:error, "Unexpected AMI Response"}
        end

      _ ->
        Logger.error("AMI connection not established")
        {:error, "AMI connection error"}
    end
  end

  def transfer_call(channel, exten) do
    action =
      ElixirAmi.Action.new("BlindTransfer", %{
        channel: channel,
        context: Application.get_env(:asterisk_connector, :context),
        exten: exten
      })

    connection = Keyword.get(Application.get_env(:asterisk_connector, :ami), :name)

    case ElixirAmi.Connection.ready?(connection) do
      true ->
        case ElixirAmi.Connection.send_action(connection, action) do
          %ElixirAmi.Response{success: true, keys: %{"message" => message}} ->
            Logger.info("#{message}\nCall transfered: #{channel} -> #{exten}")
            {:ok, message}

          %ElixirAmi.Response{keys: %{"message" => message}} ->
            Logger.error("AMI error: #{message}")
            {:error, "AMI error: #{message}"}

          error ->
            Logger.error("Unexpected AMI response: #{inspect(error)}")
            {:error, "Unexpected AMI Response"}
        end

      _ ->
        Logger.error("AMI connection not established")
        {:error, "AMI connection error"}
    end
  end

  def start_recording_call(channel, call_details) do
    file_name =
      "#{call_details.caller.name}_#{call_details.callee.name}_#{Date.utc_today()}#{call_details.call_id}.wav"

    path =
      Path.expand("priv/recordings/#{file_name}")

    action = ElixirAmi.Action.new("MixMonitor", %{channel: channel, file: path})
    ElixirAmi.Connection.send_action(:asterisk_connection, action)
    _record_link = "http://localhost:4001/recordings/#{file_name}"
  end

  def calculate_new_metrics(current_metrics, keys) do
    max_rtt =
      case Map.get(keys, "rtt") do
        nil -> current_metrics.max_rtt
        rtt -> max(String.to_float(rtt), current_metrics.max_rtt)
      end

    sent = keys["sentpackets"] |> String.to_integer()

    max_loss =
      case Map.get(keys, "report0cumulativelost") do
        nil ->
          current_metrics.max_loss

        loss ->
          loss
          |> loss_calc(sent)
          |> max(current_metrics.max_loss)
      end

    r_factor = 100 - (max_rtt / 10 + 2 * max_loss)

    %{max_rtt: max_rtt, max_loss: max_loss, r_factor: r_factor, quality: quality(r_factor)}
  end

  defp loss_calc(loss, sent) do
    loss
    |> String.to_integer()
    |> Kernel./(sent)
    |> Kernel.*(100)
  end

  defp quality(r_factor) when r_factor >= 80, do: "good"
  defp quality(r_factor) when r_factor >= 60, do: "medium"
  defp quality(_), do: "low"
end

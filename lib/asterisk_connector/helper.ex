defmodule AsteriskConnector.Helper do
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

defmodule AsteriskConnector.EventLogger do
  defp create_directory_if_not_exist(path_to_directory) do
    File.mkdir_p!(path_to_directory)
  end

  def log_event(event) do
    dir_path = Path.expand("priv/logs/")
    create_directory_if_not_exist(dir_path)

    file_path = Path.join(dir_path, "#{event.keys["linkedid"]}.log")
    event_str = "[#{DateTime.utc_now()}] #{inspect(event, pretty: true)}"
    File.write(file_path, "#{event_str}\n", [:append])
  end
end

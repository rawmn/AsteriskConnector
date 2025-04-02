defmodule AsteriskConnector.Api do

  def post(url, body) do
    Req.post(url, json: body)
    |> handle_response()
  end

  def get(url) do
    Req.get(url)
    |> handle_response()
  end

  defp handle_response({:ok, %{body: body}}) do
    IO.puts("Ответ: #{body}")
    {:ok, body}
  end

  defp handle_response({:error, reason}) do
    IO.puts("Ответ: #{reason}")
    {:error, reason}
  end
end

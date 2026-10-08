defmodule Room.A2aTask do
  @moduledoc """
  A2A JSON-RPC task send after resolve → card URL.

  Ghost fails before send (`task=none`). Distinct from
  a2a_card / a2a_resolve / a2a_resolve_dns (those stop
  at the card URL). Off Match / wiki / mint.
  """

  def look_resolve(rec \\ %{}) do
    handle = rec[:handle] || rec[:resolve] || "kai@mazel"
    url = rec[:card_url] || Room.A2aCard.card_url(handle)
    "ok  a2a  resolve=#{handle}  card_url=#{url}"
  end

  def look_send, do: "ok  task=send  to=card_url  status=ok"
  def look_ghost, do: "error  resolve=@ghost  error=unknown_handle  task=none"

  def look(pack \\ %{}) do
    [look_resolve(pack[:hit] || %{}), look_send(), look_ghost()]
  end

  @doc """
  JSON-RPC message/send to a resolved card URL.
  Unknown handle never sends.
  """
  def send(hit, text \\ "hello")

  def send(%{card_url: url, handle: handle}, text)
      when is_binary(url) and is_binary(handle) do
    rpc = rpc_send(text)

    cond do
      url != Room.A2aCard.card_url(handle) ->
        {:error, :unknown_handle}

      true ->
        case Room.A2aCard.fetch(handle) do
          {200, %{"ok" => true}} ->
            case Room.A2aTaskRpcError.rpc_reply(handle, rpc) do
              {:rpc_error, reply} ->
                {:error, Room.A2aTaskRpcError.denied(handle, url, rpc, reply)}

              :ok ->
                {:ok,
                 %{
                   ok: true,
                   task: "send",
                   to: "card_url",
                   status: :ok,
                   card_url: url,
                   method: rpc["method"],
                   jsonrpc: "2.0"
                 }}
            end

          _ ->
            {:error, :unknown_handle}
        end
    end
  end

  def send(_, _), do: {:error, :unknown_handle}

  @doc """
  Resolve kai → send task to card URL. Ghost never tasks.
  Isolated. Sibling resolve / card LOOK stays.
  """
  def demo(_opts \\ []) do
    with {:ok, hit} <- Room.A2aResolve.resolve("@kai"),
         {:ok, sent} <- send(hit),
         {:error, :unknown_handle} <- Room.A2aResolve.resolve("@ghost") do
      cond do
        hit.handle != "kai@mazel" or hit.card_url != Room.A2aCard.card_url("kai@mazel") ->
          {:error, :resolve_miss}

        sent.status != :ok or sent.to != "card_url" or sent.card_url != hit.card_url ->
          {:error, :task_miss}

        sent.method != "message/send" ->
          {:error, :rpc_miss}

        Room.A2aTask.send({:error, :unknown_handle}) != {:error, :unknown_handle} ->
          {:error, :ghost_sent}

        true ->
          pack = %{hit: hit, sent: sent, ghost: :unknown_handle}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp rpc_send(text) do
    %{
      "jsonrpc" => "2.0",
      "id" => "a2a-task",
      "method" => "message/send",
      "params" => %{
        "message" => %{
          "role" => "user",
          "parts" => [%{"kind" => "text", "text" => to_string(text)}]
        }
      }
    }
  end
end

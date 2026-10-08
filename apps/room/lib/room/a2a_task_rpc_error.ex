defmodule Room.A2aTaskRpcError do
  @moduledoc """
  Card resolves; JSON-RPC message/send returns error.

  Fixture rpcerr@mazel serves a valid card URL. The
  endpoint replies with a JSON-RPC error (not 404 /
  bad_json / transport). Clear status=error. Never
  crash. Distinct from a2a_task (status=ok), card-url
  edges (task=none), and DNS miss. Off Match / wiki /
  mint / Consent / Session / Install.
  """

  @handle "rpcerr@mazel"

  def handle, do: @handle

  def card_url, do: Room.A2aCard.card_url(@handle)

  def card do
    %{
      "ok" => true,
      "handle" => @handle,
      "skills" => ["find"]
    }
  end

  @doc "rpcerr fixture card, or :none for other handles."
  def card_for(raw) do
    if rpcerr_handle?(raw), do: {:ok, card()}, else: :none
  end

  def look_resolve(rec \\ %{}) do
    handle = rec[:handle] || @handle
    url = rec[:card_url] || card_url()
    "ok  a2a  resolve=#{handle}  card_url=#{url}"
  end

  def look_send, do: "error  task=send  to=card_url  status=error"
  def look_crash(rec \\ %{}), do: Room.A2aSkillsEmpty.look_crash(rec)

  def look(pack \\ %{}) do
    [look_resolve(pack[:hit] || %{}), look_send(), look_crash(pack)]
  end

  def rpc_error_body(rpc \\ %{}) do
    %{
      "jsonrpc" => "2.0",
      "id" => rpc["id"] || "a2a-task",
      "error" => %{"code" => -32603, "message" => "Internal error"}
    }
  end

  @doc "JSON-RPC reply for message/send. rpcerr is an error object."
  def rpc_reply(handle, rpc \\ %{}) do
    if rpcerr_handle?(handle) do
      {:rpc_error, rpc_error_body(rpc)}
    else
      :ok
    end
  end

  def denied(handle, url, rpc, reply) do
    %{
      ok: false,
      task: "send",
      to: "card_url",
      status: :error,
      crash: false,
      handle: handle,
      card_url: url,
      method: rpc["method"] || "message/send",
      jsonrpc: "2.0",
      error: reply["error"] || reply[:error]
    }
  end

  @doc """
  message/send after a resolved card. JSON-RPC error is
  status=error / crash=false. Unexpected raise is the
  same, never an exception.
  """
  def send(hit, text \\ "hello") do
    try do
      case Room.A2aTask.send(hit, text) do
        {:error, %{status: :error, crash: false} = rec} ->
          {:ok, rec}

        {:ok, sent} ->
          {:ok, Map.put(sent, :crash, false)}

        {:error, reason} ->
          {:ok,
           %{
             ok: false,
             task: "send",
             to: "card_url",
             status: :error,
             crash: false,
             error: reason
           }}
      end
    rescue
      _ ->
        {:ok, %{ok: false, task: "send", to: "card_url", status: :error, crash: false}}
    end
  end

  @doc """
  rpcerr@mazel resolves; send is JSON-RPC error; no crash.
  Isolated. Sibling task / card_404 / bad_json / dns_miss
  LOOK stays.
  """
  def demo(_opts \\ []) do
    with {:ok, hit} <- Room.A2aCard.resolve(@handle),
         {:ok, sent} <- send(hit) do
      reply = rpc_error_body(%{"id" => "a2a-task"})

      cond do
        hit.handle != @handle ->
          {:error, :handle_miss}

        hit.card_url != card_url() ->
          {:error, :url_miss}

        hit.card["ok"] != true ->
          {:error, :card_miss}

        Room.A2aCard.fetch(@handle) != {200, card()} ->
          {:error, :fetch_miss}

        Room.A2aCard.fetch_url(card_url()) != {200, card()} ->
          {:error, :url_fetch}

        rpc_reply(@handle, %{"id" => "a2a-task"}) != {:rpc_error, reply} ->
          {:error, :rpc_miss}

        rpc_reply("kai@mazel") != :ok ->
          {:error, :kai_rpc}

        sent.status != :error or sent.to != "card_url" or sent.task != "send" ->
          {:error, :task_miss}

        sent.method != "message/send" or sent.crash != false or sent.ok != false ->
          {:error, :rpc_miss}

        sent.error != reply["error"] ->
          {:error, :rpc_body}

        sent.card_url != hit.card_url ->
          {:error, :id_drift}

        match?({:error, %{status: :error, crash: false}}, Room.A2aTask.send(hit)) == false ->
          {:error, :wired_miss}

        Room.A2aCard.resolve("gone@mazel") != {:error, :card_404} ->
          {:error, :sibling_404}

        Room.A2aCard.resolve("junk@mazel") != {:error, :bad_json} ->
          {:error, :sibling_json}

        Room.A2aCard.resolve("@ghost") != {:error, :unknown_handle} ->
          {:error, :ghost_miss}

        true ->
          pack = %{hit: hit, sent: sent, crash: false, handle: @handle, card_url: card_url()}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp rpcerr_handle?(raw) do
    local =
      raw
      |> to_string()
      |> String.trim()
      |> String.trim_leading("@")
      |> String.split("@")
      |> hd()

    local == "rpcerr"
  end
end
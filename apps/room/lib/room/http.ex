defmodule Room.Http do
  @moduledoc "Bandit plug: demo board, room JSON, SSE fanout."
  use Plug.Router

  plug(Plug.Logger)
  plug(:put_secret)
  plug(:cors)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason, pass: ["application/json"])
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, File.read!(index_path()))
  end

  options _ do
    send_resp(conn, 204, "")
  end

  get "/health" do
    json(conn, 200, %{ok: true, service: "mazel-room", bind: "0.0.0.0"})
  end

  get "/v0" do
    json(conn, 200, %{
      ok: true,
      service: "mazel-room",
      endpoints: [
        %{id: "mazel_find", method: "GET", path: "/v0/find"},
        %{id: "mazel_resolve", method: "POST", path: "/v0/resolve"},
        %{id: "mazel_wing", method: "POST", path: "/v0/wing"},
        %{id: "mazel_need", method: "POST", path: "/v0/need"},
        %{id: "mazel_open", method: "POST", path: "/v0/open"},
        %{id: "mazel_badge", method: "POST", path: "/v0/rooms/:id/badge"},
        %{id: "mazel_consent", method: "POST", path: "/v0/rooms/:id/consent"},
        %{id: "mazel_warm_packet", method: "GET", path: "/v0/rooms/:id/warm_packet"},
        %{id: "mazel_agent_card", method: "GET", path: "/.well-known/agent-card.json"},
        %{id: "mazel_card", method: "GET", path: "/v0/card"},
        %{id: "mazel_a2a", method: "POST", path: "/a2a"}
      ]
    })
  end

  get "/.well-known/agent-card.json" do
    conn = fetch_query_params(conn)
    gateway_card(conn, conn.query_params["handle"])
  end

  get "/.well-known/agent.json" do
    conn = fetch_query_params(conn)
    gateway_card(conn, conn.query_params["handle"])
  end

  post "/a2a" do
    gateway_task(conn, body(conn))
  end

  post "/v0/a2a" do
    gateway_task(conn, body(conn))
  end

  get "/v0/card" do
    conn = fetch_query_params(conn)
    gateway_card(conn, conn.query_params["handle"])
  end

  get "/v0/openapi.json" do
    json(conn, 200, Room.Http.Openapi.spec())
  end

  get "/v0/find" do
    conn = fetch_query_params(conn)

    v0(conn, fn -> Room.Tools.find(conn.query_params["query"] || conn.query_params["q"] || "") end)
  end

  post "/v0/find" do
    v0(conn, fn -> Room.Tools.find(body(conn)["query"] || body(conn)["q"] || "") end)
  end

  post "/v0/resolve" do
    v0(conn, fn -> Room.Tools.resolve(body(conn)["handle"] || "") end)
  end

  post "/v0/wing" do
    params = body(conn)
    v0(conn, fn -> Room.Tools.wing(params["text"] || "", params["from"]) end)
  end

  post "/v0/need" do
    params = body(conn)
    v0(conn, fn -> Room.Tools.need(params["text"] || "", params["ttl_hours"]) end)
  end

  post "/v0/open" do
    params = body(conn)
    v0(conn, fn -> Room.Tools.open(params["text"] || "", params) end)
  end

  post "/v0/rooms/:id/badge" do
    params = body(conn)
    reply(conn, Room.Tools.badge(id, params["badge"] || params["postage"] || params))
  end

  post "/v0/rooms/:id/postage" do
    reply(
      conn,
      Room.Tools.badge(
        id,
        conn.body_params["badge"] || conn.body_params["postage"] || conn.body_params
      )
    )
  end

  post "/v0/rooms/:id/consent" do
    handle = conn.body_params["handle"] || conn.body_params["id"]
    reply(conn, Room.Tools.consent(id, handle || ""))
  end

  post "/v0/rooms/:id/commit" do
    reply(
      conn,
      Room.Tools.commit(
        id,
        conn.body_params["summary"],
        conn.body_params["transcript_excerpt"] || []
      )
    )
  end

  get "/v0/rooms/:id/warm_packet" do
    reply(conn, Room.Tools.warm_packet(id))
  end

  post "/demo" do
    {:ok, state} = Room.Demo.run()
    json(conn, 200, encode_state(state))
  end

  get "/rooms/:id" do
    case Room.get(id) do
      {:ok, state} -> json(conn, 200, encode_state(state))
      {:error, _} -> json(conn, 404, %{error: "room_not_found"})
    end
  end

  post "/rooms" do
    body = conn.body_params
    context_id = body["context_id"] || "room-" <> random_id()
    kind = body["session_kind"] || "direct"
    participants = body["participants"] || []

    case Room.open(context_id, kind, participants) do
      {:ok, state} -> json(conn, 201, encode_state(state))
      {:error, reason} -> json(conn, 400, %{error: reason})
    end
  end

  post "/rooms/:id/badge" do
    reply(conn, Room.submit_badge(id, conn.body_params))
  end

  post "/rooms/:id/postage" do
    reply(conn, Room.submit_badge(id, conn.body_params))
  end

  post "/rooms/:id/events" do
    type = conn.body_params["type"]
    payload = conn.body_params["payload"] || conn.body_params

    result =
      case type do
        "morph.propose" ->
          Room.propose_morph(id, payload["from"] || payload["handle"])

        "consent" ->
          Room.consent(id, payload["handle"] || payload)

        "morph.commit" ->
          Room.commit_morph(id, payload["summary"] || "", payload["transcript_excerpt"] || [])

        _ ->
          {:error, :unknown_event}
      end

    reply(conn, result)
  end

  get "/rooms/:id/stream" do
    conn =
      conn
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)

    Phoenix.PubSub.subscribe(Room.PubSub, Room.topic(id))

    case Room.get(id) do
      {:ok, state} -> chunk_event(conn, "snapshot", encode_state(state))
      _ -> :ok
    end

    stream_loop(conn)
  end

  match _ do
    json(conn, 404, %{error: "not_found"})
  end

  defp gateway_card(conn, handle) do
    case Room.Gateway.agent_card(handle) do
      {:ok, card} ->
        body =
          card
          |> Map.put(:ok, true)
          |> Room.Gateway.with_public_base(Room.Gateway.public_base(conn))

        json(conn, 200, body)

      {:error, reason} ->
        json(conn, 404, %{ok: false, error: gateway_error(reason)})
    end
  end

  defp gateway_task(conn, params) do
    case Room.Gateway.task(params) do
      {:ok, envelope} -> json(conn, 200, envelope)
      {:error, reason} -> json(conn, 400, %{ok: false, error: gateway_error(reason)})
    end
  end

  defp gateway_error(reason) when is_binary(reason), do: reason
  defp gateway_error(:unknown_handle), do: "unknown_handle"
  defp gateway_error({:unknown_handle, _, _}), do: "unknown_handle"
  defp gateway_error(:empty_message), do: "empty_message"
  defp gateway_error({:not_a_person, _, _, _}), do: "not_a_person"
  defp gateway_error({:invalid_card, _, _, _, _}), do: "invalid_card"
  defp gateway_error({:invalid_card, _, _}), do: "invalid_card"
  defp gateway_error(:fixture_handle), do: "fixture_handle"
  defp gateway_error(:missing_peer), do: "missing_peer"
  defp gateway_error(:rpc_method), do: "rpc_method"
  defp gateway_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp gateway_error(_), do: "error"

  defp v0(conn, fun) do
    case fun.() do
      {:ok, payload} -> json(conn, 200, payload)
      {:error, :not_found} -> json(conn, 404, %{ok: false, error: "not_found"})
      {:error, reason} -> json(conn, 400, %{ok: false, error: to_string(reason)})
    end
  end

  defp body(%{body_params: params}) when is_map(params), do: params
  defp body(_), do: %{}

  defp reply(conn, {:ok, state}), do: json(conn, 200, encode_state(state))
  defp reply(conn, {:error, :not_found}), do: json(conn, 404, %{ok: false, error: "not_found"})
  defp reply(conn, {:error, reason}), do: json(conn, 400, %{ok: false, error: to_string(reason)})

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  defp encode_state(state) do
    Jason.decode!(Jason.encode!(state))
  end

  defp chunk_event(conn, event, data) do
    Plug.Conn.chunk(conn, "event: #{event}\ndata: #{Jason.encode!(data)}\n\n")
  end

  defp stream_loop(conn) do
    receive do
      {:room_event, event, state} ->
        case chunk_event(conn, "room", %{event: event, room: encode_state(state)}) do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end
    after
      30_000 ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end
    end
  end

  defp index_path do
    Path.join(:code.priv_dir(:room), "static/index.html")
  end

  defp cors(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, authorization")
  end

  defp put_secret(conn, _opts) do
    Plug.Conn.put_private(conn, :plug_secret_key_base, String.duplicate("m", 64))
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end

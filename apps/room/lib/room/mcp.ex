defmodule Room.Mcp do
  @moduledoc """
  Thin MCP adapter (JSON-RPC 2.0 over stdio). Tools call Room.Tools.

  Add Mazel in the agent. Mazel is ready. Then `mazel_find` / `mazel_wing`.
  """

  @protocol "2024-11-05"

  @tools [
    %{
      name: "mazel_find",
      description:
        "Find a handle or a skill. Query @kai / kai@mazel or skill id series-a|cto|impl|enterprise|find|chat|direct. No live DNS.",
      inputSchema: %{
        type: "object",
        properties: %{query: %{type: "string", description: "@kai or series-a"}},
        required: ["query"]
      }
    },
    %{
      name: "mazel_resolve",
      description: "Resolve @name or name@mazel to Agent Card URL(s). Unknown handles soft-fail.",
      inputSchema: %{
        type: "object",
        properties: %{handle: %{type: "string", description: "@kai or kai@mazel"}},
        required: ["handle"]
      }
    },
    %{
      name: "mazel_wing",
      description:
        "Parse a wing command. 🪽 @kai → Direct. 🪽 @mazel → Need. 🪽 @open → Open. Not a messenger.",
      inputSchema: %{
        type: "object",
        properties: %{
          text: %{type: "string", description: "e.g. 🪽 @kai hello"},
          from: %{type: "string", description: "optional speaker handle, default @ariel"}
        },
        required: ["text"]
      }
    },
    %{
      name: "mazel_need",
      description:
        "Dispatch a discovery Need (hard TTL) and JIT-rank knows + live opens. Same as 🪽 @mazel …",
      inputSchema: %{
        type: "object",
        properties: %{
          text: %{type: "string", description: "series-A CTO"},
          ttl_hours: %{type: "integer", description: "hard TTL, default 72"}
        },
        required: ["text"]
      }
    },
    %{
      name: "mazel_open",
      description:
        "Publish live TTL openness (ping me for …). JIT-matches live needs. Same as 🪽 @open …",
      inputSchema: %{
        type: "object",
        properties: %{
          text: %{type: "string", description: "ping me for enterprise AI impl"},
          ttl_hours: %{type: "integer", description: "live TTL, default 72"},
          handle: %{type: "string", description: "who is open, default kai@mazel"}
        },
        required: ["text"]
      }
    },
    %{
      name: "mazel_badge",
      description:
        "Attach and validate a badge on an existing room. Required before consent/morph.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string"},
          badge: %{type: "object", description: "Vouch | PullIntent | InviteToken | ProofOfWork"}
        },
        required: ["context_id", "badge"]
      }
    },
    %{
      name: "mazel_consent",
      description:
        "Grant consent for a handle. Soft-fails if a badge is missing. Reports dual_consent.",
      inputSchema: %{
        type: "object",
        properties: %{
          context_id: %{type: "string"},
          handle: %{type: "string"}
        },
        required: ["context_id", "handle"]
      }
    },
    %{
      name: "mazel_warm_packet",
      description: "Return the warm packet for a committed morph room.",
      inputSchema: %{
        type: "object",
        properties: %{context_id: %{type: "string"}},
        required: ["context_id"]
      }
    }
  ]

  def tools, do: @tools
  def tool_names, do: Enum.map(@tools, & &1.name)

  @doc """
  Add-Mazel wing LOOK. Quiet ready, then find → mazel'd on the MCP tools.
  """
  def look(kai_find, kai_wing, nova_find, nova_wing) do
    [
      "Mazel is ready.",
      find_look("series-a", kai_find),
      wing_look(kai_wing),
      find_look("impl", nova_find),
      wing_look(nova_wing)
    ]
  end

  def find_look(query, found) when is_map(found) do
    "ok  mcp=mazel_find  query=#{query}→#{hit_handle(found)}"
  end

  def wing_look(wing) when is_map(wing) do
    "ok  mcp=mazel_wing  #{Room.Find.mazel_d(wing[:handle] || wing["handle"])}"
  end

  defp hit_handle(%{hits: [hit | _]}), do: hit.handle || hit[:handle]
  defp hit_handle(%{handle: handle}) when is_binary(handle), do: handle
  defp hit_handle(%{"handle" => handle}) when is_binary(handle), do: handle
  defp hit_handle(_), do: ""

  def stdio do
    Logger.configure_backend(:console, device: :standard_error)
    loop()
  end

  def handle_rpc(%{"method" => "initialize", "id" => id}) do
    reply(id, %{
      protocolVersion: @protocol,
      capabilities: %{tools: %{}},
      serverInfo: %{name: "mazel", version: "0.1.0"}
    })
  end

  def handle_rpc(%{"method" => "notifications/initialized"}), do: :noreply
  def handle_rpc(%{"method" => "initialized"}), do: :noreply

  def handle_rpc(%{"method" => "ping", "id" => id}), do: reply(id, %{})

  def handle_rpc(%{"method" => "tools/list", "id" => id}) do
    reply(id, %{tools: @tools})
  end

  def handle_rpc(%{"method" => "tools/call", "id" => id, "params" => params}) do
    name = params["name"]
    args = params["arguments"] || %{}

    case call_tool(name, args) do
      {:ok, payload} ->
        reply(id, tool_result(payload, false))

      {:error, reason} ->
        reply(id, tool_result(%{ok: false, error: to_string(reason)}, true))
    end
  end

  def handle_rpc(%{"id" => id}) do
    %{
      jsonrpc: "2.0",
      id: id,
      error: %{code: -32601, message: "method not found"}
    }
  end

  def handle_rpc(_), do: :noreply

  def call_tool("mazel_find", args) do
    with :ok <- unlock(args) do
      Room.Tools.find(args["query"] || args["handle"] || args["skill"] || "")
    end
  end

  def call_tool("mazel_resolve", args), do: Room.Tools.resolve(args["handle"] || "")

  def call_tool("mazel_wing", args) do
    with :ok <- unlock(args) do
      Room.Tools.wing(args["text"] || "", args["from"])
    end
  end
  def call_tool("mazel_need", args), do: Room.Tools.need(args["text"] || "", args["ttl_hours"])
  def call_tool("mazel_open", args), do: Room.Tools.open(args["text"] || "", args)

  def call_tool("mazel_badge", args) do
    Room.Tools.badge(args["context_id"] || "", args["badge"] || args["postage"] || %{})
  end

  def call_tool("mazel_postage", args) do
    Room.Tools.badge(args["context_id"] || "", args["badge"] || args["postage"] || %{})
  end

  def call_tool("mazel_consent", args) do
    Room.Tools.consent(args["context_id"] || "", args["handle"] || "")
  end

  def call_tool("mazel_warm_packet", args), do: Room.Tools.warm_packet(args["context_id"] || "")
  def call_tool(_, _), do: {:error, :unknown_tool}

  @doc """
  mazel_find / mazel_wing unlock at one proof Has or one Need.
  Same threshold as Toolbelt.ready?/1. When index/install
  exists, Add Mazel must be pressed first. Default root is
  the repo.
  """
  def unlock(args \\ %{}) do
    root = args["root"] || args[:root] || Room.Index.repo_root()
    Room.Install.unlock(root)
  end

  defp tool_result(payload, is_error) do
    %{
      content: [%{type: "text", text: Jason.encode!(payload)}],
      isError: is_error
    }
  end

  defp reply(id, result), do: %{jsonrpc: "2.0", id: id, result: result}

  defp loop do
    case IO.binread(:stdio, :line) do
      :eof -> :ok
      {:error, _} -> :ok
      line -> handle_line(IO.iodata_to_binary(line))
    end
  end

  defp handle_line(line) do
    cond do
      String.starts_with?(line, "Content-Length:") ->
        len =
          line
          |> String.trim()
          |> String.split(":")
          |> List.last()
          |> String.trim()
          |> String.to_integer()

        skip_headers()
        body = IO.binread(:stdio, len)
        write_framed(dispatch_body(IO.iodata_to_binary(body)))
        loop()

      String.trim(line) == "" ->
        loop()

      true ->
        write_ndjson(dispatch_body(String.trim(line)))
        loop()
    end
  end

  defp skip_headers do
    case IO.binread(:stdio, :line) do
      :eof ->
        :ok

      line ->
        if String.trim(IO.iodata_to_binary(line)) == "", do: :ok, else: skip_headers()
    end
  end

  defp dispatch_body(body) do
    case Jason.decode(body) do
      {:ok, msg} -> handle_rpc(msg)
      {:error, _} -> :noreply
    end
  end

  defp write_ndjson(:noreply), do: :ok

  defp write_ndjson(msg) do
    IO.binwrite(:stdio, [Jason.encode!(msg), ?\n])
  end

  defp write_framed(:noreply), do: :ok

  defp write_framed(msg) do
    encoded = Jason.encode!(msg)
    IO.binwrite(:stdio, ["Content-Length: #{byte_size(encoded)}\r\n\r\n", encoded])
  end
end

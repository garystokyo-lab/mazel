defmodule Room.InstallAddMazelFriendCardPaste do
  @moduledoc """
  Friend-can-try paste: one block into the AI
  they already use. Writes a real Agent Card
  with handle + Need/Have and, when they have
  one, their own reachable `/a2a` talk url.

  rpc is not the card document. No mix+repo
  friend path. Not kai/buddy. Off LOOK remint /
  first-drop lock / share remint / Group /
  Trust / Match / invented public_host.
  """

  alias Room.A2aPeerCard, as: PeerCard
  alias Room.A2aPeerResolve, as: PeerResolve
  alias Room.InstallAddMazelFriendPublicHostReady, as: HostReady

  @paste_rel ".cursor/add-mazel-friend-card.md"
  @fixture_ids ["kai@mazel", "buddy@mazel"]

  @one_liner "Paste this into the AI you already use."

  @locked """
  Paste this into the AI you already use.

  **Your Mazel Agent Card**

  Help this person try Mazel. Do not send them to clone a repo. Do not ask them to run mix.

  1. Ask their handle (who they are as an agent, like lea@peer), one Need, and one Have — in their words.
  2. Write one Agent Card JSON with:
     - handle — them
     - need / have — those tags
     - protocol — haah
     - url — where this card document (the JSON) lives. That is the card file, not talk.
     - rpc — their own reachable /a2a talk URL, only if they already have one. That is their agent runtime. It is not the card document. It is not a catalog page.
  3. If they have no reachable talk URL yet, leave rpc off. Do not invent a host. Do not set rpc to the same value as url.
  4. Give them the JSON to keep and share. Agents talk first. People join only if both say yes.

  ```json
  {
    "handle": "lea@peer",
    "url": "https://peer.example/cards/lea",
    "rpc": "https://your-agent.example/a2a",
    "protocol": "haah",
    "need": ["impl"],
    "have": ["direct"]
  }
  ```
  """

  def paste_rel, do: @paste_rel
  def one_liner, do: @one_liner
  def locked, do: @locked

  @doc "Exact tracked paste a friend copies into their AI."
  def probe_paste(root) when is_binary(root) do
    path = Path.join(root, @paste_rel)

    cond do
      not File.regular?(path) ->
        {:error, :paste_missing}

      not tracked?(root, @paste_rel) ->
        {:error, :paste_untracked}

      true ->
        text = File.read!(path)

        cond do
          not String.contains?(text, @one_liner) ->
            {:error, :one_liner_miss}

          text != @locked ->
            {:error, :paste_copy}

          forbidden?(text) ->
            {:error, :friend_path}

          not String.contains?(text, "rpc") or not String.contains?(text, "card document") ->
            {:error, :rpc_miss}

          not String.contains?(text, "need") or not String.contains?(text, "have") ->
            {:error, :need_have_miss}

          true ->
            {:ok, %{path: path, text: text, rel: @paste_rel}}
        end
    end
  end

  def probe_paste(_), do: {:error, :root_miss}

  @doc """
  Apply the paste: write a real-handle Agent Card.
  rpc is their reachable /a2a when given, else none.
  """
  def apply(opts) when is_list(opts) do
    handle = opts[:handle]
    rpc = blank_to_nil(opts[:rpc])
    url = blank_to_nil(opts[:url])
    need = Keyword.get(opts, :need, [])
    have = Keyword.get(opts, :have, [])

    with {:ok, parsed} <- parse_peer(handle),
         card <-
           PeerCard.talk_card(parsed.id,
             rpc: rpc,
             url: url,
             need: need,
             have: have
           ),
         {:ok, peer} <- PeerCard.from_map(card),
         :ok <- refuse_same(peer),
         {:ok, hit} <- PeerResolve.from_card(card),
         :ok <- maybe_write(opts[:path], parsed, card) do
      probed = HostReady.probe_host()

      {:ok,
       %{
         handle: peer.handle,
         need: peer.need,
         have: peer.have,
         url: peer.url,
         rpc: peer.rpc,
         card: card,
         hit: hit,
         public_host: probed.public_host,
         live_host_ready: probed.live_host_ready,
         paste_rel: @paste_rel
       }}
    end
  end

  def apply(_), do: {:error, :bad_opts}

  defp parse_peer(raw) do
    case Room.Wings.parse_handle(to_string(raw || "")) do
      {:ok, handle} ->
        if handle.id in @fixture_ids do
          {:error, :fixture_handle}
        else
          {:ok, handle}
        end

      error ->
        error
    end
  end

  defp refuse_same(%{url: url, rpc: rpc}) when is_binary(url) and is_binary(rpc) do
    if url == rpc, do: {:error, :rpc_none}, else: :ok
  end

  defp refuse_same(_), do: :ok

  defp maybe_write(nil, _, _), do: :ok

  defp maybe_write(path, parsed, card) when is_binary(path) do
    dest =
      if File.dir?(path) or String.ends_with?(path, "/") do
        File.mkdir_p!(path)
        Path.join(path, local_name(parsed.id) <> ".json")
      else
        File.mkdir_p!(Path.dirname(path))
        path
      end

    local = local_name(parsed.id)

    if local in ["kai", "buddy"] do
      {:error, :fixture_handle}
    else
      File.write!(dest, Jason.encode!(card, pretty: true) <> "\n")
      :ok
    end
  end

  defp maybe_write(_, _, _), do: {:error, :bad_path}

  defp local_name(id) do
    id |> String.split("@") |> hd()
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(_), do: nil

  defp forbidden?(text) do
    String.contains?(text, "@kai") or
      String.contains?(text, "@buddy") or
      String.contains?(text, "kai@mazel") or
      String.contains?(text, "buddy@mazel") or
      String.contains?(text, "127.0.0.1") or
      String.contains?(text, "localhost") or
      String.contains?(text, "raw.githubusercontent") or
      String.contains?(text, "mazel.ai/") or
      String.contains?(text, "/workspace") or
      String.contains?(text, "apps/room") or
      String.contains?(text, "cwd") or
      String.contains?(String.downcase(text), "mix mcp") or
      String.contains?(String.downcase(text), "npx")
  end

  defp tracked?(root, rel) do
    case System.cmd("git", ["-C", root, "ls-files", "--error-unmatch", "--", rel],
           stderr_to_stdout: true
         ) do
      {_, 0} -> true
      _ -> false
    end
  end
end
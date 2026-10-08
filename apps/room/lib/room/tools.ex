defmodule Room.Tools do
  @moduledoc """
  MCP / HTTP v0 facade. Calls Room.Wings and Room — does not reimplement the spine.
  """

  def find(query), do: Room.Find.query(query)

  def resolve(handle) when is_binary(handle) do
    handle = String.trim(handle)

    if handle == "" do
      {:ok, %{ok: false, handle: "", card_urls: [], error: "empty_handle"}}
    else
      do_resolve(handle)
    end
  end

  def resolve(_), do: {:ok, %{ok: false, handle: "", card_urls: [], error: "empty_handle"}}

  defp do_resolve(handle) do
    case Room.Wings.resolve(handle) do
      {:ok, found} ->
        if Map.get(found, :sink) do
          sink_kind = found[:sink_kind] || "need"

          {:ok,
           %{
             ok: true,
             handle: found.id,
             sink: sink_kind,
             kind: sink_kind <> "_sink",
             card_urls: [],
             error: nil
           }}
        else
          {:ok,
           %{
             ok: true,
             handle: found.id,
             card_urls: List.wrap(found.card_url),
             source: found[:source] && to_string(found.source),
             haah: found[:haah] == true,
             txt: found[:txt],
             error: nil
           }}
        end

      {:error, reason} ->
        {:ok, fail(reason, %{handle: handle, card_urls: []})}
    end
  end

  def wing(text, from \\ nil) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      {:ok, %{ok: false, error: "empty_text"}}
    else
      opts = if is_binary(from) and from != "", do: [from: from], else: []

      case Room.Wings.run(text, opts) do
        {:ok, result} -> {:ok, encode_result(result)}
        {:error, reason} -> {:ok, fail(reason)}
      end
    end
  end

  def need(text, ttl_hours \\ nil) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      {:ok, %{ok: false, kind: "need", error: "empty_text"}}
    else
      case Room.Need.dispatch(text, ttl_hours: Room.Index.ttl_hours(ttl_hours, 72)) do
        {:ok, result} -> {:ok, encode_result(result)}
        {:error, reason} -> {:ok, %{ok: false, kind: "need", error: to_string(reason)}}
      end
    end
  end

  def open(text, opts \\ []) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      {:ok, %{ok: false, kind: "open", error: "empty_text"}}
    else
      ttl = opts[:ttl_hours] || opts["ttl_hours"]
      handle = opts[:handle] || opts["handle"] || "kai@mazel"

      root = opts[:root] || opts["root"]

      case Room.Open.dispatch(text, ttl_hours: ttl, handle: handle, root: root) do
        {:ok, result} -> {:ok, encode_result(result)}
        {:error, reason} -> {:ok, %{ok: false, kind: "open", error: to_string(reason)}}
      end
    end
  end

  def badge("", _badge), do: {:error, :not_found}

  def badge(context_id, badge) when is_binary(context_id) do
    case Room.get(context_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, _} ->
        case Room.submit_badge(context_id, badge) do
          {:ok, state} -> {:ok, dump(state)}
          other -> other
        end
    end
  end

  def postage(context_id, badge), do: badge(context_id, badge)

  def consent(context_id, handle) when is_binary(context_id) do
    case Room.get(context_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, state} ->
        cond do
          is_nil(state.badge) ->
            {:error, :badge_required}

          true ->
            case Room.consent(context_id, handle) do
              {:ok, next} -> {:ok, dump(next)}
              other -> other
            end
        end
    end
  end

  def warm_packet(context_id) when is_binary(context_id) do
    case Room.get(context_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, %{warm_packet: nil}} ->
        {:error, :not_committed}

      {:ok, state} ->
        {:ok, dump(state.warm_packet)}
    end
  end

  def commit(context_id, summary, transcript \\ []) do
    case Room.get(context_id) do
      {:error, :not_found} -> {:error, :not_found}
      {:ok, %{badge: nil}} -> {:error, :badge_required}
      {:ok, _} -> Room.commit_morph(context_id, summary || "", transcript || [])
    end
    |> case do
      {:ok, state} -> {:ok, dump(state)}
      other -> other
    end
  end

  def dump(term), do: Jason.decode!(Jason.encode!(term))

  defp encode_result(%{open_id: _} = open) do
    %{
      ok: true,
      kind: "open",
      open_id: open.open_id,
      sink: open[:sink] || "open@mazel",
      handle: open[:handle],
      topic: open.topic,
      ttl_hours: open.ttl_hours,
      expires_at: open.expires_at,
      path: open[:path],
      matches: dump(open.matches),
      badge: dump(open[:badge]),
      expired: open[:expired] || false
    }
  end

  defp encode_result(%{need_id: _} = need) do
    %{
      ok: true,
      kind: "need",
      need_id: need.need_id,
      sink: need[:sink] || "need@mazel",
      topic: need.topic,
      ttl_hours: need.ttl_hours,
      expires_at: need.expires_at,
      path: need[:path],
      matches: dump(need.matches),
      badge: dump(need[:badge]),
      expired: need[:expired] || false
    }
  end

  defp encode_result(%{command: cmd, speaker: speaker, target: target, state: state}) do
    kind = state.session_kind

    %{
      ok: true,
      kind: kind,
      context_id: state.context_id,
      session_kind: kind,
      wings: state.wings,
      from: speaker.id,
      handle: target.id,
      card_url: target.card_url,
      source: source_id(target),
      text: cmd.text,
      badge: dump(state.badge),
      events: Enum.map(state.events, & &1.type),
      dual_consent: state.dual_consent,
      status: state.status,
      warm_packet: dump(state.warm_packet)
    }
  end

  defp fail(reason, extra \\ %{}) do
    extra
    |> Map.merge(%{ok: false, error: error_id(reason)})
    |> maybe_reason(reason)
  end

  defp maybe_reason(map, {:invalid_card, _path, reason}),
    do: Map.put(map, :reason, to_string(reason))

  defp maybe_reason(map, {:invalid_card, _role, _raw, _path, reason}),
    do: Map.put(map, :reason, to_string(reason))

  defp maybe_reason(map, _), do: map

  defp error_id(:unknown_handle), do: "unknown_handle"
  defp error_id({:invalid_card, _, _}), do: "invalid_card"
  defp error_id({:invalid_card, _, _, _, _}), do: "invalid_card"
  defp error_id({:unknown_handle, _, _}), do: "unknown_handle"
  defp error_id({:missing_card, _, _}), do: "missing_card"
  defp error_id({:not_a_person, _, _, _}), do: "not_a_person"
  defp error_id(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_id(reason) when is_binary(reason), do: reason
  defp error_id(_), do: "error"

  defp source_id(%{source: source}) when not is_nil(source), do: to_string(source)
  defp source_id(_), do: nil
end

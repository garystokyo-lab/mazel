defmodule Room.TalkWarm do
  @moduledoc """
  Talk → morph → warm strip → return-to-agent.

  Extends talk_return with Warm.fields. Does not rewrite
  talk_return / warm_pull / warm_packet LOOK.
  """

  def look(pack) when is_map(pack) do
    Room.TalkNoMorph.look(pack) ++
      Room.Warm.fields("ariel@mazel", "kai@mazel", pack.state) ++
      [Room.Return.look(pack[:wrapped])]
  end

  def look(_), do: look(%{badge: %{}, state: %{}})

  @doc """
  Same talk→morph path, then warm fields, then wrap.
  Isolated. Sibling LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "talk-warm-" <> random_id()

    excerpt = Keyword.get(opts, :excerpt) || [%{text: "Ariel is up."}]

    with {:ok, talk} <- Room.TalkNoMorph.demo(context_id: prefix, excerpt: excerpt),
         {:ok, wrapped} <- Room.Return.wrap(talk.state.context_id) do
      cond do
        wrapped.status != :returned or wrapped.morph != "closed" ->
          {:error, :no_return}

        wrapped.session != "agent" ->
          {:error, :session_miss}

        Room.Warm.fields("ariel@mazel", "kai@mazel", talk.state) == [] ->
          {:error, :warm_miss}

        true ->
          pack = Map.merge(talk, %{wrapped: wrapped})
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp random_id do
    Integer.to_string(System.unique_integer([:positive]), 16)
  end
end

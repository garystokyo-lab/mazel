defmodule Room.TalkReturn do
  @moduledoc """
  Talk → no-morph → stamp → morph.commit → return-to-agent.

  Extends talk_no_morph with the wrap beat. Does not rewrite
  talk_no_morph / return / return_pull LOOK.
  """

  def look(pack) when is_map(pack) do
    Room.TalkNoMorph.look(pack) ++ [Room.Return.look(pack[:wrapped])]
  end

  def look(_), do: look(%{badge: %{}})

  @doc """
  Same talk→morph path, then humans drop back.
  Isolated. Sibling LOOK stays.
  """
  def demo(opts \\ []) do
    prefix = Keyword.get(opts, :context_id) || "talk-ret-" <> random_id()

    with {:ok, talk} <- Room.TalkNoMorph.demo(context_id: prefix),
         {:ok, wrapped} <- Room.Return.wrap(talk.state.context_id) do
      cond do
        wrapped.status != :returned or wrapped.morph != "closed" ->
          {:error, :no_return}

        wrapped.session != "agent" ->
          {:error, :session_miss}

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

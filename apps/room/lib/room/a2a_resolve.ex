defmodule Room.A2aResolve do
  @moduledoc """
  A2A resolve compose: handle → well-known → card URL.

  Distinct from a2a_card (well-known serves / URL print),
  a2a_card_skills (skills on card), and resolve_card
  (TXT / HAAH / mazel'd). Off Match / wiki / mint.
  """

  def look_resolve(rec \\ %{}) do
    handle = rec[:handle] || rec[:resolve] || "kai@mazel"
    via = rec[:via] || "well-known"
    "ok  a2a  resolve=#{handle}  via=#{via}"
  end

  def look_url(rec \\ %{}) do
    url = rec[:card_url] || Room.A2aCard.card_url("kai@mazel")
    "ok  card_url=#{url}"
  end

  def look_ghost, do: "error  resolve=@ghost  error=unknown_handle"

  def look(pack \\ %{}) do
    hit = pack[:hit] || %{}
    [look_resolve(hit), look_url(hit), look_ghost()]
  end

  @doc "Handle in → well-known fetch → card URL out. Ghost misses."
  def resolve(handle) do
    case Room.A2aCard.resolve(handle) do
      {:ok, hit} ->
        {:ok, Map.merge(hit, %{via: "well-known", resolve: hit.handle})}

      error ->
        error
    end
  end

  @doc """
  Compose kai handle to card URL via well-known. Ghost 404.
  Isolated. Sibling card / skills / TXT LOOK stays.
  """
  def demo(_opts \\ []) do
    with {:ok, hit} <- resolve("@kai"),
         {:error, :unknown_handle} <- resolve("@ghost") do
      cond do
        hit.handle != "kai@mazel" or hit.resolve != "kai@mazel" ->
          {:error, :handle_miss}

        hit.via != "well-known" ->
          {:error, :via_miss}

        hit.card_url != Room.A2aCard.card_url("kai@mazel") ->
          {:error, :url_miss}

        hit.path != Room.A2aCard.path() ->
          {:error, :path_miss}

        hit.card["ok"] != true ->
          {:error, :card_miss}

        true ->
          pack = %{hit: hit, ghost: :unknown_handle}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end

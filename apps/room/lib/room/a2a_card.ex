defmodule Room.A2aCard do
  @moduledoc """
  A2A Agent Card via `/.well-known/agent-card.json`.

  Handle → card URL. Ghost is unknown_handle. Distinct from
  card_well_known / resolve_card (HAAH / TXT / mazel'd).
  Off Match / wiki / mint.
  """

  @path "/.well-known/agent-card.json"

  def path, do: @path

  def card_url(handle) do
    local = handle |> to_string() |> String.trim_leading("@") |> String.split("@") |> hd()
    "https://#{local}.mazel.ai#{@path}"
  end

  def look_well_known, do: "ok  a2a  well-known=#{@path}"

  def look_handle(rec \\ %{}) do
    handle = rec[:handle] || rec["handle"] || "kai@mazel"
    url = rec[:card_url] || rec["card_url"] || card_url(handle)
    "ok  handle=#{handle}  card_url=#{url}"
  end

  def look_ghost, do: "error  handle=@ghost  error=unknown_handle"

  def look(pack \\ %{}) do
    [look_well_known(), look_handle(pack[:hit] || %{}), look_ghost()]
  end

  @doc "In-process GET of the A2A well-known card. No live bind."
  def fetch(handle) do
    case Room.A2aTaskCard404.fetch(handle) do
      {404, body} ->
        {404, body}

      :none ->
        case Room.A2aTaskCardBadJson.fetch(handle) do
          {200, body} ->
            {200, body}

          :none ->
            case Room.A2aTaskCardNoUrl.fetch(handle) do
              {200, body} ->
                {200, body}

              :none ->
                case Room.A2aTaskCardEmptyUrl.fetch(handle) do
                  {200, body} ->
                    {200, body}

                  :none ->
                    case Room.A2aTaskCardWsUrl.fetch(handle) do
                      {200, body} ->
                        {200, body}

                      :none ->
                        case Room.A2aTaskCardPadUrl.fetch(handle) do
                          {200, body} ->
                            {200, body}

                          :none ->
                            case Room.A2aTaskCardBadScheme.fetch(handle) do
                              {200, body} ->
                                {200, body}

                              :none ->
                                case Room.A2aTaskCardFtpUrl.fetch(handle) do
                                  {200, body} ->
                                    {200, body}

                                  :none ->
                                    case Room.A2aTaskCardFileUrl.fetch(handle) do
                                      {200, body} ->
                                        {200, body}

                                      :none ->
                                        case Room.A2aSkillsEmpty.card_for(handle) do
                                          {:ok, body} ->
                                            {200, body}

                                          :none ->
                                            case Room.A2aSkillsMissingKey.card_for(handle) do
                                              {:ok, body} ->
                                                {200, body}

                                              :none ->
                                                case Room.A2aSkillsNull.card_for(handle) do
                                                  {:ok, body} ->
                                                    {200, body}

                                                  :none ->
                                                    case Room.A2aSkillsString.card_for(handle) do
                                                      {:ok, body} ->
                                                        {200, body}

                                                      :none ->
                                                        case Room.A2aSkillsNumber.card_for(handle) do
                                                          {:ok, body} ->
                                                            {200, body}

                                                          :none ->
                                                            case Room.A2aSkillsObject.card_for(handle) do
                                                              {:ok, body} ->
                                                                {200, body}

                                                              :none ->
                                                                case Room.A2aSkillsMixed.card_for(handle) do
                                                                  {:ok, body} ->
                                                                    {200, body}

                                                                  :none ->
                                                                    case Room.A2aTaskRpcError.card_for(handle) do
                                                                      {:ok, body} -> {200, body}
                                                                      :none ->
                                                                        case Room.A2aBuddyCard.card_for(handle) do
                                                                          {:ok, body} -> {200, body}
                                                                          :none -> Room.CardWellKnown.fetch(handle)
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
  end

  @doc "Re-fetch the Agent Card from a resolved card URL."
  def fetch_url(url) when is_binary(url) do
    case handle_from_url(url) do
      {:ok, handle} ->
        if url == card_url(handle) do
          fetch(handle)
        else
          {404, %{"error" => "unknown_handle"}}
        end

      :error ->
        {404, %{"error" => "unknown_handle"}}
    end
  end

  def fetch_url(_), do: {404, %{"error" => "unknown_handle"}}

  defp handle_from_url(url) do
    uri = URI.parse(url)
    host = uri.host || ""

    if uri.path == @path and String.ends_with?(host, ".mazel.ai") do
      local = String.replace_suffix(host, ".mazel.ai", "")
      {:ok, local <> "@mazel"}
    else
      :error
    end
  end

  @doc "Handle → A2A card URL after well-known serves. Ghost misses."
  def resolve(handle) do
    case fetch(handle) do
      {200, body} when not is_map(body) ->
        {:error, :bad_json}

      {200, body} ->
        cond do
          Room.A2aTaskCardNoUrl.no_url?(body) ->
            {:error, :no_url}

          Room.A2aTaskCardEmptyUrl.empty_url?(body) ->
            {:error, :empty_url}

          Room.A2aTaskCardWsUrl.ws_url?(body) ->
            {:error, :empty_url}

          Room.A2aTaskCardPadUrl.pad_url?(body) ->
            {:ok, Room.A2aTaskCardPadUrl.hit(body)}

          Room.A2aTaskCardBadScheme.bad_scheme?(body) ->
            {:error, :bad_scheme}

          Room.A2aTaskCardFtpUrl.ftp_url?(body) ->
            {:error, :bad_scheme}

          Room.A2aTaskCardFileUrl.file_url?(body) ->
            {:error, :bad_scheme}

          true ->
            id = body["handle"]

            {:ok,
             %{
               handle: id,
               card_url: card_url(id),
               path: @path,
               card: body
             }}
        end

      {404, %{"error" => "card_404"}} ->
        {:error, :card_404}

      {404, %{"error" => "unknown_handle"}} ->
        {:error, :unknown_handle}

      _ ->
        {:error, :unknown_handle}
    end
  end

  @doc """
  Well-known serves kai's Agent Card. Ghost 404.
  Isolated. Sibling HAAH / TXT LOOK stays.
  """
  def demo(_opts \\ []) do
    with {:ok, hit} <- resolve("@kai"),
         {:error, :unknown_handle} <- resolve("@ghost") do
      bindings = hit.card["bindings"] || []
      binding = List.first(bindings) || %{}

      cond do
        hit.handle != "kai@mazel" ->
          {:error, :handle_miss}

        hit.card_url != card_url("kai@mazel") ->
          {:error, :url_miss}

        hit.path != @path ->
          {:error, :path_miss}

        hit.card["ok"] != true ->
          {:error, :card_miss}

        binding["protocolBinding"] != "JSONRPC" or binding["url"] != "/a2a" ->
          {:error, :binding_miss}

        true ->
          pack = %{hit: hit, ghost: :unknown_handle}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end

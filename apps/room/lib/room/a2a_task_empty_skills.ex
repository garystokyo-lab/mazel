defmodule Room.A2aTaskEmptySkills do
  @moduledoc """
  Task send to an empty-skills card still ok. No crash.

  Reuses empty@mazel. Distinct from a2a_task (kai with
  skills) and a2a_skills_empty (list only). Off Match /
  wiki / mint.
  """

  @handle Room.A2aSkillsEmpty.handle()

  def handle, do: @handle

  def look_resolve(rec \\ %{}), do: Room.A2aSkillsEmpty.look_resolve(rec)
  def look_skills(rec \\ %{}), do: Room.A2aSkillsEmpty.look_skills(rec)
  def look_send, do: Room.A2aTask.look_send()

  def look(pack \\ %{}) do
    [look_resolve(pack[:hit] || %{}), look_skills(pack[:from_url] || %{}), look_send()]
  end

  @doc """
  JSON-RPC message/send to a resolved empty-skills card.

  Empty skills still send. Unexpected raise is denied /
  crash=false, not an exception.
  """
  def send(hit, text \\ "hello") do
    try do
      case Room.A2aTask.send(hit, text) do
        {:ok, sent} ->
          {:ok, Map.put(sent, :crash, false)}

        {:error, reason} ->
          {:ok,
           %{
             ok: false,
             task: "send",
             to: "card_url",
             status: :denied,
             crash: false,
             error: reason
           }}
      end
    rescue
      _ ->
        {:ok, %{ok: false, task: "send", to: "card_url", status: :denied, crash: false}}
    end
  end

  @doc """
  empty@mazel resolves; skills=none; task send ok.
  Isolated. Sibling task / skills_empty LOOK stays.
  """
  def demo(_opts \\ []) do
    with {:ok, hit} <- Room.A2aCard.resolve(@handle),
         {:ok, from_url} <- Room.A2aSkillsEmpty.from_url(hit),
         {:ok, sent} <- send(hit) do
      cond do
        hit.handle != @handle ->
          {:error, :handle_miss}

        hit.card_url != Room.A2aSkillsEmpty.card_url() ->
          {:error, :url_miss}

        hit.card["ok"] != true ->
          {:error, :card_miss}

        Room.A2aCardSkills.of(hit.card) != {:error, :empty_skills} ->
          {:error, :not_empty}

        from_url.skills != :none or from_url.crash != false ->
          {:error, :skills_listed}

        sent.status != :ok or sent.to != "card_url" or sent.card_url != hit.card_url ->
          {:error, :task_miss}

        sent.method != "message/send" or sent.crash != false ->
          {:error, :rpc_miss}

        true ->
          pack = %{hit: hit, from_url: from_url, sent: sent, crash: false}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end

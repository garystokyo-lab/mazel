defmodule Room.ToolbeltReady do
  @moduledoc """
  Add-Mazel MCP as soon as one proof Has or one Need exists.

  mazel_find / mazel_wing unlock at the toolbelt gate.
  Paste is Cursor / Grok / Hermes / Muse.
  Curious never unlocks. Does not rewrite toolbelt / mcp / install LOOK.
  """

  def look_empty, do: "error  empty  mcp=not_ready"

  def look_has(found) when is_map(found) do
    hit = List.first(found[:hits] || [])
    handle = (hit && hit.handle) || "kai@mazel"
    "ok  has=1  mcp=mazel_find  query=series-a→#{handle}"
  end

  def look_need(found) when is_map(found) do
    hit = List.first(found[:hits] || [])
    handle = (hit && hit.handle) || "kai@mazel"
    "ok  need=1  mcp=mazel_find  query=series-a→#{handle}"
  end

  def look_wing(wing) when is_map(wing) do
    "ok  mcp=mazel_wing  #{Room.Find.mazel_d(wing[:handle] || wing["handle"] || "kai@mazel")}"
  end

  def look_paste do
    brains = Room.Install.brains() |> Enum.map(&to_string/1) |> Enum.join("|")
    "ok  paste=#{brains}"
  end

  def look(pack) when is_map(pack) do
    [look_empty(), look_has(pack.has_find), look_need(pack.need_find), look_wing(pack.wing), look_paste()]
  end

  def look(_) do
    look(%{
      has_find: %{hits: [%{handle: "kai@mazel"}]},
      need_find: %{hits: [%{handle: "kai@mazel"}]},
      wing: %{handle: "kai@mazel"}
    })
  end

  @doc """
  Empty vault is not_ready. One proof Has or one Need unlocks
  mazel_find / mazel_wing. Isolated. Switzerland pastes stay.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-toolbelt-ready-#{System.unique_integer([:positive])}")
          File.mkdir_p!(path)
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    empty = Path.join(root, "empty")
    has_root = Path.join(root, "has")
    need_root = Path.join(root, "need")
    File.mkdir_p!(Path.join(empty, "index/has"))
    File.mkdir_p!(Path.join(has_root, "index/has"))
    File.mkdir_p!(Path.join(need_root, "index/needs"))

    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(has_root, "index/has/kai.md")
    )

    with {:error, :not_ready} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => empty}),
         {:ok, _} <- Room.Need.seed("founders-investors", root: need_root),
         {:ok, has_find} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => has_root}),
         {:ok, need_find} <- Room.Mcp.call_tool("mazel_find", %{"query" => "series-a", "root" => need_root}),
         {:ok, wing} <-
           Room.Mcp.call_tool("mazel_wing", %{"text" => Room.Find.wing_at("kai@mazel"), "root" => has_root}) do
      has_hit = List.first(has_find[:hits] || [])
      need_hit = List.first(need_find[:hits] || [])
      pastes = Enum.map(Room.Install.brains(), &Room.Install.load/1)

      cond do
        Room.Toolbelt.ready?(empty) or Room.Toolbelt.proof_has_count(empty) != 0 or
            Room.Toolbelt.need_count(empty) != 0 ->
          {:error, :empty_ready}

        Room.Toolbelt.proof_has_count(has_root) < 1 or Room.Toolbelt.need_count(has_root) != 0 or
            not Room.Toolbelt.ready?(has_root) ->
          {:error, :has_miss}

        Room.Toolbelt.need_count(need_root) < 1 or Room.Toolbelt.proof_has_count(need_root) != 0 or
            not Room.Toolbelt.ready?(need_root) ->
          {:error, :need_miss}

        is_nil(has_hit) or has_hit.handle != "kai@mazel" ->
          {:error, :has_find_miss}

        is_nil(need_hit) or need_hit.handle != "kai@mazel" ->
          {:error, :need_find_miss}

        (wing[:handle] || wing["handle"]) != "kai@mazel" ->
          {:error, :wing_miss}

        Enum.any?(pastes, &match?({:error, _}, &1)) ->
          {:error, :paste_miss}

        Room.Install.brains() != [:cursor, :grok, :hermes, :muse] ->
          {:error, :brains_miss}

        true ->
          pack = %{has_find: has_find, need_find: need_find, wing: wing, has: 1, need: 1}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end

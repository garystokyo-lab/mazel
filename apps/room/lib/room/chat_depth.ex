defmodule Room.ChatDepth do
  @moduledoc """
  High-turn chat → structured Has / factor inputs.

  Only tagged `proof:` lines count. Not chat-BM25, not message
  similarity, not embeddings. Quant ranks the inputs. Self-report
  alone stays curious.
  """

  @min_turns 6
  @need %{id: "chat-depth", kind: "need", wants: ["series-a"]}
  @meta_tags ~w(proof claim source skills trail check)

  def min_turns, do: @min_turns
  def need, do: @need
  def chat_rel, do: "priv/fixtures/kai.chat_depth.txt"
  def self_rel, do: "priv/fixtures/kai.self_report.txt"

  def extract(raw, opts \\ []) when is_binary(raw) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()
    path = resolve(raw, root)

    case File.read(path) do
      {:ok, text} ->
        {:ok, from_text(text, Room.Has.display_path(path))}

      {:error, _} ->
        {:error, :bad_file}
    end
  end

  def from_text(text, file \\ "") when is_binary(text) do
    turns = count_turns(text)
    bodies = bodies(text)
    proof = tagged_proof(bodies)
    claim = tagged_claim(bodies)
    source = "chat_depth"
    provenance = Room.Has.provenance_for(source)

    # Tagged proof only. Untagged mentions / boasts / claims stay off Has.
    # High-turn is required — a short self-report never graduates.
    cond do
      proof == [] or turns < @min_turns ->
        %{
          ok: false,
          status: "curious",
          kind: "curious",
          source: source,
          provenance: provenance,
          turns: turns,
          skills: [],
          proof: [],
          claim: claim,
          file: file,
          reason: "self_report",
          curious: true,
          unfit: true
        }

      true ->
        %{
          ok: true,
          status: "has",
          kind: "has",
          source: source,
          provenance: provenance,
          turns: turns,
          skills: proof,
          proof: proof,
          claim: claim,
          file: file,
          reason: "chat_depth",
          unfit: false
        }
    end
  end

  def inputs(rec, wants \\ @need.wants) do
    overlap = overlap_of(rec, wants)

    %{
      fit: if(overlap != [], do: 1, else: 0),
      heat: 0,
      fresh: 1,
      trail: 0,
      check: 0
    }
  end

  @doc """
  Named Factor inputs for `Room.Score.gather/3`. Extract fills
  fit / gates. Quant ranks. Chat text is never a factor.
  """
  def factor_inputs(rec, wants \\ @need.wants) do
    rec
    |> inputs(wants)
    |> Map.merge(%{
      curious: rec[:curious] == true or rec[:status] == "curious",
      unfit: rec[:unfit] == true,
      claim: rec[:reason] == "self_report" and rec[:proof] == []
    })
  end

  def overlap_of(rec, wants \\ @need.wants) do
    Enum.filter(List.wrap(wants), &(&1 in List.wrap(rec[:skills] || rec[:proof])))
  end

  @doc """
  Extract → `Room.Score.of/3` → `Room.Factors.score/2`.
  Same gather path as trail/check. Isolated from Has I/O heat.
  """
  def score_of(rec, opts \\ []) when is_map(rec) do
    handle = Keyword.get(opts, :handle) || "kai@mazel"
    need = Keyword.get(opts, :need) || @need

    match = %{
      handle: handle,
      overlap: overlap_of(rec, need[:wants] || @need.wants),
      extract: rec,
      source: rec[:source],
      status: rec[:status],
      curious: rec[:curious],
      unfit: rec[:unfit]
    }

    Room.Score.of(handle, match, Keyword.merge([need: need, extract: rec], opts))
  end

  def look_extract(rec) do
    listed = Enum.join(rec[:skills] || rec[:proof] || [], ",")
    "ok  extract=chat_depth  turns=#{rec[:turns] || 0}  has=[#{listed}]"
  end

  def look_inputs(rec) do
    named = Room.Factors.score(inputs(rec)).inputs

    "ok  provenance=chat_depth  inputs={fit:#{named.fit},heat:#{named.heat},fresh:#{named.fresh},trail:#{Map.get(named, :trail, 0)}}"
  end

  def look_match(rec) do
    scored = Room.Factors.score(inputs(rec))
    "ok  need×has  peer=kai@mazel  score=#{scored.score}"
  end

  def look_self(%{unfit: true}), do: "error  self_report→curious  unfit=true"
  def look_self(_), do: "error  self_report→curious  unfit=true"

  def look(pack) when is_map(pack) do
    [look_extract(pack.chat), look_inputs(pack.chat), look_match(pack.chat), look_self(pack.self)]
  end

  def look_score_inputs(_rec, scored) when is_map(scored) do
    named = scored[:inputs] || scored[:factors] || %{}
    "ok  inputs=#{Room.Factors.format_inputs(named, :all)}  provenance=chat_depth"
  end

  def look_score_match(scored) when is_map(scored) do
    peer = scored[:handle] || scored[:peer] || "kai@mazel"
    "ok  need×has  peer=#{peer}  score=#{scored[:score] || 0}"
  end

  def look_score(pack) when is_map(pack) do
    [
      look_extract(pack.chat),
      look_score_inputs(pack.chat, pack.score),
      look_score_match(pack.score),
      look_self(pack.self)
    ]
  end

  @doc """
  High-turn extract vs self-report. Isolated. No chat ranking.
  """
  def demo(opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    with {:ok, chat} <- extract(chat_rel(), root: root),
         {:ok, self} <- extract(self_rel(), root: root) do
      scored = Room.Factors.score(inputs(chat))

      cond do
        chat.status != "has" or chat.source != "chat_depth" or chat.provenance != "chat" ->
          {:error, :chat_miss}

        self.status != "curious" or not self.unfit ->
          {:error, :self_not_curious}

        scored.unfit ->
          {:error, :chat_unfit}

        true ->
          pack = %{chat: chat, self: self, score: scored}
          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  @doc """
  Extract → Score.gather → Factors.score. Named inputs include
  trail/check (stay 0). Self-report is unfit. Isolated.
  """
  def score_demo(opts \\ []) do
    root = Keyword.get(opts, :root) || Room.Index.repo_root()

    with {:ok, chat} <- extract(chat_rel(), root: root),
         {:ok, self} <- extract(self_rel(), root: root) do
      scored = score_of(chat, root: root, handle: "kai@mazel")
      self_scored = score_of(self, root: root, handle: "kai@mazel")
      named = scored.inputs

      cond do
        chat.status != "has" or chat.source != "chat_depth" ->
          {:error, :chat_miss}

        self.status != "curious" or not self.unfit ->
          {:error, :self_not_curious}

        scored.unfit ->
          {:error, :chat_unfit}

        not self_scored.unfit ->
          {:error, :self_fit}

        named.fit != 1 or named.heat != 0 or named.trail != 0 or named.check != 0 ->
          {:error, :bad_inputs}

        true ->
          pack = %{
            chat: chat,
            self: self,
            score: Map.merge(scored, %{handle: "kai@mazel", peer: "kai@mazel"}),
            self_score: self_scored
          }

          {:ok, Map.put(pack, :lines, look_score(pack))}
      end
    end
  end

  def count_turns(text) when is_binary(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.count(&speaker_turn?/1)
  end

  defp bodies(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.map(&strip_speaker/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp tagged_proof(bodies) do
    bodies
    |> Enum.filter(&tag?(&1, "proof:"))
    |> Enum.flat_map(ids_after("proof:"))
    |> Enum.uniq()
    |> Enum.filter(&(&1 in Room.Has.domain_skills()))
  end

  defp tagged_claim(bodies) do
    tagged =
      bodies
      |> Enum.filter(&tag?(&1, "claim:"))
      |> Enum.map(&strip_tag(&1, "claim:"))

    boasts = Enum.filter(bodies, &boast?/1)
    (tagged ++ boasts) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq()
  end

  defp ids_after(prefix) do
    fn line ->
      line
      |> strip_tag(prefix)
      |> String.split(~r/[,]+/, trim: true)
      |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
      |> Enum.reject(&(&1 == ""))
    end
  end

  defp tag?(line, prefix), do: String.starts_with?(String.downcase(line), prefix)

  defp strip_tag(line, prefix) do
    if tag?(line, prefix) do
      String.slice(line, String.length(prefix)..-1//1) |> String.trim()
    else
      line
    end
  end

  defp boast?(line) do
    Regex.match?(~r/^(i am |i'm |as a )/i, line) or
      Regex.match?(~r/\b(passionate|visionary|thought[- ]leader|world-class|guarantee|#1|best in class)\b/i, line)
  end

  # Speaker turns only. Do not count bare `proof:` / `claim:` tags as a turn.
  defp speaker_turn?(line) do
    case Regex.run(~r/^([a-z][a-z0-9_-]*):/i, line) do
      [_, who] -> String.downcase(who) not in @meta_tags
      _ -> false
    end
  end

  defp strip_speaker(line) do
    trimmed = String.trim(line)

    case Regex.run(~r/^([a-z][a-z0-9_-]*):\s*(.*)$/i, trimmed) do
      [_, who, rest] ->
        if String.downcase(who) in @meta_tags, do: trimmed, else: String.trim(rest)

      _ ->
        trimmed
    end
  end

  defp resolve(raw, root) do
    cond do
      File.regular?(raw) -> raw
      File.regular?(Path.join(root, raw)) -> Path.join(root, raw)
      true -> Path.join(Room.Index.repo_root(), raw)
    end
  end
end

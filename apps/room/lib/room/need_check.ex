defmodule Room.NeedCheck do
  @moduledoc """
  Built-in prompt-check on Need cast / Need×Has.

  Transcript claim or contradiction → curious, never matches.
  Check runs on cast and on match decorate — not a later filter.
  Not BM25. Not Has upload-check.
  """

  @claim ~r/\b(claim:|vibe:|passionate|visionary|thought[- ]leader)\b/i

  def look_pass(%{ok: true, handle: handle}) when is_binary(handle) do
    "ok  need×has  peer=#{handle}  check=pass"
  end

  def look_pass(_), do: "ok  need×has  peer=  check=pass"

  def look_claim, do: "error  claim→curious  unfit=true"
  def look_contradict, do: "error  contradict→curious  unfit=true"

  def look(pack) when is_map(pack) do
    [look_pass(pack.match), look_claim(), look_contradict()]
  end

  def look(_), do: look(%{match: %{}})

  @doc """
  Need cast, then prompt-check the transcript. Claim / contradict
  land curious before any match.
  """
  def cast(raw, opts \\ []) do
    transcript = transcript_of(raw, opts)

    with {:ok, need} <- Room.Need.Shape.cast(raw) do
      check(need, transcript)
    end
  end

  @doc """
  Check a Need against a transcript. Claim / contradict → curious.
  """
  def check(need, transcript \\ "") when is_map(need) do
    text = to_string(transcript)

    cond do
      Room.Need.curious?(need) or claim?(text) ->
        {:ok, refuse(need, "claim")}

      contradict?(need, text) ->
        {:ok, refuse(need, "contradict")}

      true ->
        {:ok, Map.merge(need, %{check: "pass", unfit: false, ok: true})}
    end
  end

  @doc """
  Match-path decorate. When a transcript is present, check first.
  Curious / unfit never ranks.
  """
  def decorate(need, opts) when is_list(opts) do
    case Keyword.get(opts, :transcript) do
      t when is_binary(t) and t != "" ->
        {:ok, checked} = check(need, t)
        {checked, Keyword.delete(opts, :transcript)}

      _ ->
        {need, opts}
    end
  end

  def decorate(need, opts), do: {need, opts}

  def match_has(need, opts \\ []) do
    Room.Need.match_has(need, opts)
  end

  @doc """
  Pass Need×Has + claim / contradict. Isolated tmp.
  Does not rewrite need_demo / open_need / mvp_find / score LOOK.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-need-check-#{System.unique_integer([:positive])}")
          File.mkdir_p!(Path.join(path, "index/has"))
          {path, true}
      end

    try do
      demo_on(root)
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp demo_on(root) do
    File.cp!(
      Path.join(Room.Index.repo_root(), "index/has/kai.md"),
      Path.join(root, "index/has/kai.md")
    )

    agree = "need: founders seeking series-a"
    boast = "claim: passionate visionary hunt for series-a"
    deny = "transcript: we do not do series-a"

    with {:ok, pass} <- cast(:founder_investors, transcript: agree),
         {:ok, claim} <- cast(:founder_investors, transcript: boast),
         {:ok, contradict} <- cast(:founder_investors, transcript: deny),
         {:ok, match} <- Room.Need.match_has(pass, root: root, transcript: agree),
         {:ok, skipped} <- Room.Need.match_has(pass, root: root, transcript: boast),
         {:ok, blocked} <- Room.Need.match_has(pass, root: root, transcript: deny) do
      cond do
        pass.check != "pass" or pass.unfit ->
          {:error, :pass_miss}

        not claim.unfit or claim.reason != "claim" ->
          {:error, :claim_fit}

        not contradict.unfit or contradict.reason != "contradict" ->
          {:error, :contradict_fit}

        skipped.ok or blocked.ok or skipped.matches != [] or blocked.matches != [] ->
          {:error, :curious_matched}

        match[:unfit] or match[:check] == "claim" or match[:check] == "contradict" ->
          {:error, :pass_unfit}

        not match.ok or match.handle != "kai@mazel" ->
          {:error, :match_miss}

        true ->
          pack = %{
            pass: pass,
            claim: claim,
            contradict: contradict,
            match: Map.put(match, :check, "pass")
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end

  defp transcript_of(raw, opts) when is_list(opts) do
    Keyword.get(opts, :transcript) || (if is_binary(raw), do: raw, else: "")
  end

  defp transcript_of(_raw, transcript) when is_binary(transcript), do: transcript
  defp transcript_of(raw, _), do: if(is_binary(raw), do: raw, else: "")

  defp refuse(need, reason) do
    Map.merge(need, %{
      ok: false,
      kind: :curious,
      status: "curious",
      check: reason,
      reason: reason,
      curious: true,
      unfit: true,
      error: reason
    })
  end

  defp claim?(text), do: Regex.match?(@claim, text)

  defp contradict?(need, text) do
    wants = List.wrap(need[:wants] || need["wants"]) |> Enum.map(&to_string/1)
    down = String.downcase(text)

    Enum.any?(wants, fn want ->
      String.contains?(down, "not #{want}") or String.contains?(down, "no #{want}") or
        String.contains?(down, "do not do #{want}")
    end)
  end
end

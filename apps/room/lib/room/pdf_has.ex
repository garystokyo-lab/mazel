defmodule Room.PdfHas do
  @moduledoc """
  PDF / resume upload → Has only with non-AI artifact proof.

  Resume or claim text alone stays curious. Aligned PDF after a
  trail is Has. Conflict stays curious. Distinct from
  upload_check (check= strip), has_gh (gh+check), and
  profile_seed (url→curious).
  """

  def look_claim, do: "ok  pdf=resume  text=claim  →curious"
  def look_aligned, do: "ok  pdf=artifact  aligned→has"
  def look_conflict, do: "error  pdf=conflict  →curious"

  def look(_pack \\ %{}) do
    [look_claim(), look_aligned(), look_conflict()]
  end

  @doc """
  Resume/claim text is curious. PDF artifact after GH is Has.
  Conflict is curious. Isolated. Sibling Has LOOK stays.
  """
  def demo(opts \\ []) do
    {root, cleanup?} =
      case Keyword.fetch(opts, :root) do
        {:ok, given} ->
          {given, false}

        :error ->
          path = Path.join(System.tmp_dir!(), "mazel-pdf-has-#{System.unique_integer([:positive])}")
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
    with {:ok, resume} <-
           Room.Has.seed_resume(Room.Has.pdf_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, claim} <-
           Room.Has.seed_resume(Room.Has.fluff_rel(), handle: "kai@mazel", root: root, github: false),
         {:ok, gh} <-
           Room.Has.seed_github(Room.Has.github_rel(), handle: "kai@mazel", root: root),
         {:ok, aligned} <-
           Room.Has.seed_resume(Room.Has.pdf_rel(), handle: "kai@mazel", root: root),
         {:ok, conflict} <-
           Room.Has.seed_resume(Room.Has.conflict_rel(), handle: "kai@mazel", root: root) do
      cond do
        resume.status != "curious" or resume.reason != "resume_only" ->
          {:error, :resume_not_curious}

        resume.source != "upload" ->
          {:error, :resume_not_upload}

        claim.status != "curious" or claim.reason != "claim" ->
          {:error, :claim_not_curious}

        gh.status != "has" or gh.source != "github" ->
          {:error, :trail_miss}

        aligned.status != "has" or aligned.reason != "aligned" or aligned.source != "upload" ->
          {:error, :align_not_has}

        conflict.status != "curious" or conflict.reason != "conflict" ->
          {:error, :conflict_not_curious}

        true ->
          pack = %{
            resume: resume,
            claim: claim,
            aligned: aligned,
            conflict: conflict,
            file: Room.Has.pdf_rel()
          }

          {:ok, Map.put(pack, :lines, look(pack))}
      end
    end
  end
end

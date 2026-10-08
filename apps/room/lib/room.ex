defmodule Room do
  @moduledoc """
  In-memory morph rooms, one GenServer per context_id.

  Events: morph.propose / consent / morph.commit / morph.revoke / morph.rejoin.
  A badge is required before a human is woken. Dual consent is required before morph.
  Need and Open are discovery slices (TTL + JIT), not rooms.
  """

  @type handle :: %{id: String.t(), card_url: String.t() | nil}
  @type role :: :agent | :human

  def topic(context_id), do: "room:#{context_id}"

  def open(context_id, session_kind, participants) do
    case ensure(context_id) do
      {:ok, _} -> Room.Context.open(context_id, session_kind, participants)
      error -> error
    end
  end

  def submit_badge(context_id, badge), do: Room.Context.submit_badge(context_id, badge)
  def submit_postage(context_id, badge), do: submit_badge(context_id, badge)
  def propose_morph(context_id, from), do: Room.Context.propose_morph(context_id, from)
  def talk(context_id, from, text, opts \\ []) do
    Room.Context.talk(context_id, from, text, opts)
  end
  def consent(context_id, handle), do: Room.Context.consent(context_id, handle)
  def offline(context_id, handle), do: Room.Context.offline(context_id, handle)
  def online(context_id, handle), do: Room.Context.online(context_id, handle)
  def stamp_consent_wait(context_id, ttl, now \\ DateTime.utc_now()) do
    Room.Context.stamp_consent_wait(context_id, ttl, now)
  end

  def expire_consent_wait(context_id, now \\ DateTime.utc_now()) do
    Room.Context.expire_consent_wait(context_id, now)
  end

  def soft_no_consent_wait(context_id, handle) do
    Room.Context.soft_no_consent_wait(context_id, handle)
  end

  def commit_morph(context_id, summary, transcript) do
    Room.Context.commit_morph(context_id, summary, transcript)
  end

  def return(context_id), do: Room.Context.return(context_id)
  def revoke(context_id, from), do: Room.Context.revoke(context_id, from)
  def rejoin(context_id, badge), do: Room.Context.rejoin(context_id, badge)
  def leave(context_id, from), do: Room.Context.leave(context_id, from)
  def join(context_id, from), do: Room.Context.join(context_id, from)
  def sit_humans(context_id), do: Room.Context.sit_humans(context_id)
  def drop_humans(context_id), do: Room.Context.drop_humans(context_id)

  def get(context_id) do
    case Registry.lookup(Room.Registry, context_id) do
      [{_, _}] -> Room.Context.get(context_id)
      [] -> {:error, :not_found}
    end
  end

  def ensure(context_id) do
    case Registry.lookup(Room.Registry, context_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> start(context_id)
    end
  end

  defp start(context_id) do
    spec = %{
      id: {Room.Context, context_id},
      start: {Room.Context, :start_link, [context_id]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(Room.Contexts, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end
end

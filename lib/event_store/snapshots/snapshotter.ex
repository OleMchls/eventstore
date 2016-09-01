defmodule EventStore.Snapshots.Snapshotter do
  @moduledoc """
  Record and read snapshots of process state
  """

  use GenServer
  require Logger

  alias EventStore.Snapshots.{SnapshotData,Snapshotter}
  alias EventStore.Storage

  defstruct serializer: nil

  def start_link(serializer) do
    GenServer.start_link(__MODULE__, %Snapshotter{
      serializer: serializer
    }, name: __MODULE__)
  end

  def init(%Snapshotter{} = state) do
    {:ok, state}
  end

  @doc """
  Read a snapshot, if available, for a given source
  """
  def read_snapshot(source_uuid) do
    GenServer.call(__MODULE__, {:read_snapshot, source_uuid})
  end

  @doc """
  Record a snapshot of the data and metadata for a given source

  Returns `:ok` on success
  """
  def record_snapshot(%SnapshotData{} = snapshot) do
    GenServer.call(__MODULE__, {:record_snapshot, snapshot})
  end

  def handle_call({:read_snapshot, source_uuid}, _from, %Snapshotter{serializer: serializer} = state) do
    reply = case Storage.read_snapshot(source_uuid) do
      {:ok, snapshot} -> {:ok, deserialize_snapshot(snapshot, serializer)}
      reply -> reply
    end

    {:reply, reply, state}
  end

  def handle_call({:record_snapshot, %SnapshotData{} = snapshot}, _from, %Snapshotter{serializer: serializer} = state) do
    reply =
      snapshot
      |> serialize_snapshot(serializer)
      |> Storage.record_snapshot

    {:reply, reply, state}
  end

  defp serialize_snapshot(%SnapshotData{data: data, metadata: metadata} = snapshot, serializer) do
    %SnapshotData{snapshot |
      data: serializer.serialize(data),
      metadata: serializer.serialize(metadata)
    }
  end

  defp deserialize_snapshot(%SnapshotData{source_type: source_type, data: data, metadata: metadata} = snapshot, serializer) do
    %SnapshotData{snapshot |
      data: serializer.deserialize(data, type: source_type),
      metadata: serializer.deserialize(metadata, [])
    }
  end
end

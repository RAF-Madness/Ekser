defmodule Ekser.DHT do
  require Ekser.Node
  require Ekser.Job
  @behaviour Ekser.Serializable

  @enforce_keys [:jobs]
  defstruct [
    :nodes,
    :jobs
  ]

  defguardp is_dht(term) when is_struct(term, __MODULE__)

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    with {:ok, nodes} <- json["nodes"] |> Ekser.Serializable.json_list_to_map(Ekser.Node),
         {:ok, jobs} <- json["jobs"] |> Ekser.Serializable.json_list_to_map(Ekser.Job) do
      new(nodes, jobs)
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Failed to parse DHT."}
    end
  end

  def new(nodes, jobs) do
    with {true, _} <-
           {Ekser.Serializable.valid_map?(nodes, Ekser.Node), "Nodes must be a valid node map."},
         {true, _} <-
           {Ekser.Serializable.valid_map?(jobs, Ekser.Job), "Jobs must be a valid job map."} do
      {:ok, %__MODULE__{nodes: nodes, jobs: jobs}}
    else
      {false, message} -> {:error, message}
    end
  end

  def add_node(dht, node) when is_dht(dht) and Ekser.Node.is_node(node) do
    %__MODULE__{dht | nodes: Map.put(dht.nodes, node.id, node)}
  end

  def merge_dht(dht, other_dht) when is_dht(dht) and is_dht(other_dht) do
    %__MODULE__{
      dht
      | nodes: Map.merge(dht.nodes, other_dht.nodes),
        jobs: Map.merge(dht.jobs, other_dht.jobs)
    }
  end
end

defimpl Jason.Encoder, for: Ekser.DHT do
  def encode(value, opts) do
    map = %{nodes: value.nodes.values, jobs: value.jobs.values}

    Jason.Encode.map(map, opts)
  end
end

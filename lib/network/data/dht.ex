defmodule Ekser.DHT do
  require Ekser.Node
  require Ekser.Job
  @behaviour Ekser.Serializable

  @enforce_keys [:id, :nodes, :jobs]
  defstruct @enforce_keys

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    id = json["id"]

    nodes =
      json["nodes"]
      |> Ekser.Serializable.to_struct_map(Ekser.Node, fn node -> {node.id, node} end)

    jobs =
      json["jobs"]
      |> Ekser.Serializable.to_struct_map(Ekser.Job, fn job -> {job.name, job} end)

    new(id, nodes, jobs)
  end

  @spec new(pos_integer(), %{pos_integer() => %Ekser.Node{}}, %{String.t() => %Ekser.Job{}}) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def new(id, nodes, jobs) do
    with {true, _} <- {is_integer(id), "Node ID must be an integer."},
         {true, _} <-
           {Ekser.Serializable.valid_map?(nodes, Ekser.Node), "Nodes must be a valid node map."},
         {true, _} <-
           {Ekser.Serializable.valid_map?(jobs, Ekser.Job), "Jobs must be a valid job map."} do
      %__MODULE__{id: id, nodes: nodes, jobs: jobs}
    else
      {false, message} -> {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.DHT do
  def encode(value, opts) do
    map = Map.from_struct(value)

    Jason.Encode.map(map, opts)
  end
end

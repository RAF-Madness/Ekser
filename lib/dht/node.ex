defmodule Ekser.Node do
  require Ekser.TCP
  @behaviour Ekser.Serializable

  @enforce_keys [:ip, :port]
  defstruct [
    :id,
    :ip,
    :port,
    :fractal_id,
    :job_name
  ]

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    id = json["nodeId"]

    ip =
      json["ipAddress"]
      |> Ekser.TCP.to_ip()

    port = json["port"]
    fractal_id = json["fractalId"]
    job_name = json["jobName"]

    new(id, ip, port, fractal_id, job_name)
  end

  @spec new(integer(), tuple(), pos_integer(), String.t(), String.t()) ::
          %__MODULE__{} | {:error, String.t()}
  def new(id, ip, port, fractal_id, job_name) do
    with {true, _} <- {is_integer(id), "Node ID must be an integer."},
         {true, _} <-
           {Ekser.TCP.is_tcp_ip(ip), "Node IP must be a valid IP address."},
         {true, _} <- {Ekser.TCP.is_tcp_port(port), Ekser.TCP.port_prompt()},
         {true, _} <- {is_binary(fractal_id), "Fractal ID must be a string."},
         {true, _} <- {is_binary(job_name), "Job name must be a string."} do
      %__MODULE__{id: id, ip: ip, port: port, fractal_id: fractal_id, job_name: job_name}
    else
      {false, message} ->
        {:error, message}
    end
  end

  @spec same_node?(%__MODULE__{}, %__MODULE__{}) :: true | false
  def same_node?(node1, node2) do
    node1.id === node2.id or (node1.ip === node2.ip and node1.port === node2.port)
  end
end

defimpl String.Chars, for: Ekser.Node do
  def to_string(node) do
    string_ip = Ekser.TCP.to_ip(node.ip)
    "Node #{node.id} at #{string_ip}:#{node.port}"
  end
end

defimpl Jason.Encoder, for: Ekser.Node do
  def encode(value, opts) do
    map = %{
      "nodeId" => value.id,
      "ipAddress" => Ekser.TCP.from_ip(value.ip),
      "port" => value.port,
      "fractalId" => value.fractal_id,
      "jobName" => value.job_name
    }

    Jason.Encode.map(map, opts)
  end
end

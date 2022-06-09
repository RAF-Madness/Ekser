defmodule Ekser.Node do
  require Ekser.Util
  @behaviour Ekser.Serializable

  defstruct [
    :id,
    :ip,
    :port
  ]

  defguard is_node(term) when is_struct(term, __MODULE__)

  @impl true
  def create_from_json(json) when is_map(json) do
    id = json["id"]
    ip = json["ipAddress"]
    port = json["port"]

    new(id, ip, port)
  end

  @impl true
  def prepare_for_json(struct) when is_node(struct) do
    %{id: struct.id, ip: Ekser.Util.from_ip(struct.ip), port: struct.port}
  end

  def new(id, ip, port) do
    with {:id, true} <- {:id, is_integer(id)},
         {:ip, true} <- {:ip, Ekser.Util.is_tcp_ip(ip)},
         {:port, true} <- {:port, Ekser.Util.is_tcp_port(port)} do
      {:ok, %__MODULE__{id: id, ip: ip, port: port}}
    else
      {:id, false} ->
        {:error, "Node ID must be an integer."}

      {:ip, false} ->
        {:error,
         "Node IP must be a valid IP address represented as a tuple of separate integers."}

      {:port, false} ->
        {:error, Ekser.Util.port_prompt()}
    end
  end
end

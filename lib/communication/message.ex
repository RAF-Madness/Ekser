defmodule Ekser.Message do
  require Ekser.Node

  @behaviour Ekser.Serializable
  @callback parse_payload(payload :: any()) :: any() | {:error, String.t()}
  @callback send_effect(message :: %__MODULE__{}) ::
              :ok
              | :exit
              | {:bootstrap, function()}
              | {:send, function()}

  @enforce_keys [:type, :sender, :receiver, :routes, :payload]
  defstruct @enforce_keys

  defguard is_message(term) when is_struct(term, __MODULE__)

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    concat = &("Elixir.Ekser.Message." <> &1)

    # need this due to programmer errors
    type =
      try do
        json["type"]
        |> String.split("_")
        |> Enum.map(fn string -> String.capitalize(string) end)
        |> Enum.join()
        |> concat.()
        |> String.to_existing_atom()
      rescue
        RuntimeError -> :error
      end

    sender =
      json["sender"]
      |> Ekser.Node.create_from_json()

    receiver =
      json["receiver"]
      |> Ekser.Node.create_from_json()

    routes = json["routes"]

    payload = json["payload"]

    new(type, sender, receiver, routes, payload)
  end

  @spec new(
          String.t() | any(),
          %Ekser.Node{} | any(),
          %Ekser.Node{} | any(),
          list(integer()) | any(),
          any()
        ) ::
          %__MODULE__{} | {:error, String.t()}
  def new(type, sender, receiver, routes, payload) do
    with {true, _} <- {is_atom(type), "Provided message type is not a valid type."},
         {true, _} <- {is_struct(sender, Ekser.Node), "Provided sender is not a valid node."},
         {true, _} <-
           {is_struct(receiver, Ekser.Node), "Provided receiver is not a valid node."},
         {true, _} <-
           {is_list(routes),
            "Routes must be a list of nodes by ID which this message passed through."},
         payload when not is_tuple(payload) <- type.parse_payload(payload) do
      %__MODULE__{
        type: type,
        sender: sender,
        receiver: receiver,
        routes: routes,
        payload: payload
      }
    else
      {false, message} -> {:error, message}
      {:error, message} -> {:error, message}
    end
  end

  @spec send_effect(%__MODULE__{}) ::
          :ok | :exit | {:bootstrap, function()} | {:broadcast, function()} | {:send, function()}
  def send_effect(message) do
    message.type.send_effect(message)
  end

  @spec get_short_type(%__MODULE__{}) :: String.t()
  def get_short_type(message) do
    Atom.to_string(message.type)
    |> String.split(".")
    |> List.last()
    |> String.upcase()
  end

  @spec append_route(%__MODULE__{}, integer()) :: %__MODULE__{}
  def append_route(message, id) do
    %__MODULE__{message | routes: [id | message.routes]}
  end
end

defimpl Jason.Encoder, for: Ekser.Message do
  def encode(value, opts) do
    map = %{
      Map.from_struct(value)
      | type: Ekser.Message.get_short_type(value)
    }

    Jason.Encode.map(map, opts)
  end
end

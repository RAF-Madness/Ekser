defmodule Ekser.Message do
  require Ekser.Node
  @behaviour Ekser.Serializable

  @enforce_keys [:type, :sender, :receiver, :payload]
  defstruct [
    :type,
    :sender,
    :receiver,
    :payload
  ]

  defguard is_message(term) when is_struct(term, __MODULE__)

  @impl true
  def create_from_json(json) when is_map(json) do
    type =
      json["messageType"]
      |> String.to_existing_atom()

    sender = json["sender"]

    receiver = json["receiver"]

    payload = json["payload"]

    new(type, sender, receiver, payload)
  end

  def new(type, sender, receiver, payload) do
    with {true, _} <- {is_atom(type), "Provided message type is not a valid type."},
         {true, _} <- {is_integer(sender), "Provided sender is not a valid node."},
         {true, _} <-
           {is_integer(receiver), "Provided receiver is not a valid node."} do
      {:ok, %__MODULE__{type: type, sender: sender, receiver: receiver, payload: payload}}
    else
      {false, message} -> {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Message do
  def encode(value, opts) do
    map = %{Map.from_struct(value) | type: Atom.to_string(value.type)}

    Jason.Encode.map(map, opts)
  end
end

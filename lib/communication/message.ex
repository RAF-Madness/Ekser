defmodule Ekser.Message do
  require Ekser.Node
  @behaviour Ekser.Serializable

  @enforce_keys [:type, :sender, :receiver, :content]
  defstruct [
    :type,
    :sender,
    :receiver,
    :content
  ]

  defguard is_message(term) when is_struct(term, __MODULE__)

  @impl true
  def create_from_json(json) when is_map(json) do
    type =
      json["messageType"]
      |> String.to_existing_atom()

    sender =
      json["sender"]
      |> Ekser.Node.create_from_json()

    receiver =
      json["receiver"]
      |> Ekser.Node.create_from_json()

    content = json["content"]

    new(type, sender, receiver, content)
  end

  @impl true
  def prepare_for_json(struct) when is_message(struct) do
    %{
      messageType: Atom.to_string(struct.type),
      sender: Ekser.Node.prepare_for_json(struct.sender),
      receiver: Ekser.Node.prepare_for_json(struct.receiver),
      content: struct.content
    }
  end

  def new(type, sender, receiver, content) do
    with {:type, true} <- {:type, is_atom(type)},
         {:sender, true} <- {:sender, Ekser.Node.is_node(sender)},
         {:receiver, true} <- {:receiver, receiver === nil or Ekser.Node.is_node(receiver)},
         {:content, true} <- {:content, is_binary(content)} do
      {:ok, %__MODULE__{type: type, sender: sender, receiver: receiver, content: content}}
    else
      {:type, false} ->
        {:error, "Provided message type is not a valid type."}

      {:sender, false} ->
        {:error, "Provided sender is not a valid node."}

      {:receiver, false} ->
        {:error,
         "Provided receiver is not a valid node. If you wish to send a broadcast message, put this as nil."}

      {:content, false} ->
        {:error, "Provided content is not a valid string."}
    end
  end
end

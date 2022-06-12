defmodule Ekser.Serializable do
  @callback create_from_json(json :: map()) :: struct() | {:error, String.t()}

  def valid_map?(map, module) when is_atom(module) do
    is_map(map) and Enum.all?(Map.values(map), fn element -> is_struct(element, module) end)
  end

  @spec to_struct_map(map() | list(), atom(), (struct() -> tuple())) :: map() | :error
  def to_struct_map(map, module, kv) when is_map(map) do
    stream = Stream.map(Map.values(map), fn element -> module.create_from_json(element) end)

    case Enum.find(stream, fn element -> is_struct(element, module) end) do
      nil -> Enum.into(stream, %{}, fn element -> kv.(element) end)
      _ -> :error
    end
  end

  def to_struct_map(list, module, kv) do
    stream = Stream.map(list, fn element -> module.create_from_json(element) end)

    case Enum.find(stream, fn element -> is_struct(element, module) end) do
      nil -> Enum.into(stream, %{}, fn element -> kv.(element) end)
      _ -> :error
    end
  end
end

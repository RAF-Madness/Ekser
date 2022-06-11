defmodule Ekser.Serializable do
  @callback create_from_json(json :: map()) :: {:ok, struct()} | {:error, String.t()}
  @callback get_kv(struct :: struct()) :: tuple()
  @optional_callbacks get_kv: 1

  defguardp is_error?(term) when is_tuple(term) and elem(term, 0) === :error

  def json_list_to_map(list, module) when is_list(list) and is_atom(module) do
    with {true, _} <-
           {function_exported?(module, :get_kv, 1), "Module does not support mapping."},
         objects <- for(object <- list, do: module.create_from_json(object)),
         nil <- Enum.find(objects, &is_error?/1) do
      {:ok, Enum.into(objects, %{}, fn {:ok, object} -> module.get_kv(object) end)}
    else
      {:error, message} -> {:error, message}
      {false, message} -> {:error, message}
    end
  end

  def valid_map?(map, module) when is_atom(module) do
    is_map(map) and Enum.all?(map.values, fn element -> is_struct(element, module) end)
  end
end

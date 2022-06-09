defmodule Ekser.Serializable do
  @callback create_from_json(json :: map()) :: {:ok, struct()} | {:error, String.t()}
  @callback prepare_for_json(struct :: struct()) :: map()
end

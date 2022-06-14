defmodule Ekser.Result do
  @behaviour Ekser.Serializable
  @enforce_keys [:name, :points]
  defstruct @enforce_keys

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    name = json["name"]

    points =
      json["points"]
      |> Ekser.Point.from_json()

    new(name, points)
  end

  def new(name, points) do
    with {true, _} <- {is_binary(name), "Invalid result name."},
         {true, _} <- {Ekser.Point.valid_points?(points), "Invalid list of points."} do
      {:ok, %__MODULE__{name: name, points: points}}
    else
      {false, message} -> {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Result do
  def encode(value, opts) do
    Jason.Encode.map(value, opts)
  end
end

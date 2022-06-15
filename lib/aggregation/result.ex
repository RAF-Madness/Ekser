defmodule Ekser.Result do
  @behaviour Ekser.Serializable
  @enforce_keys [:job_name, :points]
  defstruct @enforce_keys

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    job_name = json["jobName"]

    points =
      json["points"]
      |> Ekser.Point.from_json()

    new(job_name, points)
  end

  def merge_result(map, result) do
    Map.merge(map, get_friendly(result), fn _, points1, points2 -> points1 ++ points2 end)
  end

  def get_friendly(result) do
    %{result.job_name => result.points}
  end

  def new(job_name, points) do
    with {true, _} <- {is_binary(job_name), "Invalid result name."},
         {true, _} <- {Ekser.Point.valid_points?(points), "Invalid list of points."} do
      %__MODULE__{job_name: job_name, points: points}
    else
      {false, message} -> {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Result do
  def encode(value, opts) do
    [job_name] =
      Map.keys(value)
      |> Enum.take(1)

    map = %{"jobName" => value.job_name, "points" => Ekser.Point.to_json(value.points)}

    Jason.Encode.map(map, opts)
  end
end

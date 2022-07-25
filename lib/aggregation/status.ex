defmodule Ekser.Status do
  @behaviour Ekser.Serializable
  @enforce_keys [:job_name, :fractal_id, :points_calculated]
  defstruct @enforce_keys

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    job_name = json["jobName"]

    [fractal_id] =
      json["pointsPerNode"]
      |> Map.keys()
      |> Enum.take(1)

    points_calculated = json["pointsPerNode"][fractal_id]

    new(job_name, fractal_id, points_calculated)
  end

  def merge_status(map, status) do
    Map.merge(map, get_friendly(status), fn _, nodes1, nodes2 ->
      Map.merge(nodes1, nodes2)
    end)
    |> Map.drop([""])
  end

  def get_status_string(map) do
    {all_string, all_sum} =
      Enum.reduce(Map.to_list(map), {[], 0}, fn {job_name, job_map}, {acc_string, acc_sum} ->
        {job_string, job_sum} = get_job_string(job_map)

        appended_job_acc_string = [job_string | acc_string]

        {[
           "Job ",
           job_name,
           " has a total of #{job_sum} calculated points. Distribution:" | appended_job_acc_string
         ], acc_sum + job_sum}
      end)

    ["#{all_sum} points have been calculated." | all_string]
  end

  defp get_job_string(map) do
    Enum.reduce(Map.to_list(map), {[], 0}, fn {fractal_id, points}, {acc_string, acc_sum} ->
      {["Node with fractal ID ", fractal_id, " calculated #{points} points.\n" | acc_string],
       acc_sum + points}
    end)
  end

  def get_friendly(status) do
    %{status.job_name => %{status.fractal_id => status.points_calculated}}
  end

  def new(job_name, fractal_id, points_calculated) do
    with {true, _} <- {is_binary(job_name), "Invalid job name."},
         {true, _} <- {Ekser.FractalId.valid_fractal_id?(fractal_id), "Invalid fractal id."},
         {true, _} <- {is_integer(points_calculated), "Invalid number of points calculated."} do
      %__MODULE__{
        job_name: job_name,
        fractal_id: fractal_id,
        points_calculated: points_calculated
      }
    else
      {false, message} -> {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Status do
  def encode(value, opts) do
    map = %{
      "jobName" => value.job_name,
      "pointsPerNode" => %{value.fractal_id => value.points_calculated}
    }

    Jason.Encode.map(map, opts)
  end
end

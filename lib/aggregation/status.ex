defmodule Ekser.Status do
  @behaviour Ekser.Serializable
  @enforce_keys [:job_name, :fractal_id, :points_calculated]
  defstruct @enforce_keys

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    job_name = json["jobName"]

    points_per_node = json["pointsPerNode"]

    new(job_name, points_per_node)
  end

  def merge_status(map, status) do
    Map.merge(map, get_friendly(status), fn job_name, nodes1, nodes2 ->
      Map.merge(nodes1, nodes2)
    end)
  end

  def get_status_string(map) do
    {all_string, all_sum} =
      Enum.reduce(Map.to_list(map), [], fn {job_name, job_map}, {acc_string, acc_sum} ->
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
    Enum.reduce(Map.to_list(map), [], fn {fractal_id, points}, {acc_string, acc_sum} ->
      {["Node with fractal ID ", fractal_id, " calculated #{points} points.\n" | acc_string],
       acc_sum + points}
    end)
  end

  def get_friendly(status) do
    %{status.job_name => %{status.fractal_id => status.count}}
  end

  def new(job_name, fractal_id, count) do
    %__MODULE__{job_name: job_name, fractal_id: fractal_id, count: count}
  end

  def new(job_name, points_per_node) do
    with {true, _} <- {is_binary(job_name), "Invalid job name."},
         {true, _} <-
           {is_map(points_per_node) and
              Enum.all?(Map.values(points_per_node), fn value -> is_integer(value) end),
            "Invalid map of calculated points."} do
      %__MODULE__{job_name: job_name}
    else
      {false, message} -> {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Status do
  def encode(value, opts) do
    [job_name] =
      Map.keys(value)
      |> Enum.take(1)

    map = %{job_name => Map.get(value, job_name)}

    Jason.Encode.map(map, opts)
  end
end

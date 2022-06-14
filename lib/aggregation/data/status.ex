defmodule Ekser.Status do
  @behaviour Ekser.Serializable
  @enforce_keys [:name, :job_name, :fractal_id, :points]
  defstruct @enforce_keys

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    name = json["name"]

    job_name = json["job_name"]

    fractal_id = json["fractal_id"]

    points = json["points"]

    new(name, job_name, fractal_id, points)
  end

  def new(name, job_name, fractal_id, points) do
    with {true, _} <- {is_binary(name), "Invalid status name."},
         {true, _} <- {is_binary(job_name), "Invalid job name."},
         {true, _} <- {is_binary(fractal_id), "Invalid fractal ID."},
         {true, _} <- {is_integer(points), "Invalid calculated points number."} do
      %__MODULE__{name: name, job_name: job_name, fractal_id: fractal_id, points: points}
    else
      {false, message} -> {:error, message}
    end
  end

  def compare(status1, status2) do
    cond do
      status1.job === status2.job -> :eq
      status1.job <= status2.job -> :lt
      status1.job >= status2.job -> :gt
    end
  end

  def to_iodata(term) do
    [
      term.job,
      " ",
      term.fractal_id,
      " - ",
      Integer.to_string(term.points),
      " points calculated.\n"
    ]
  end
end

defimpl String.Chars, for: Ekser.Status do
  def to_string(term) do
    "#{term.job} #{term.fractal_id} - #{term.points} points calculated."
  end
end

defimpl Jason.Encoder, for: Ekser.Status do
  def encode(value, opts) do
    Jason.Encode.map(value, opts)
  end
end

defmodule Ekser.Status do
  @enforce_keys [:job, :fractal_id, :points]
  defstruct @enforce_keys

  defguardp is_status(term) when is_struct(term, __MODULE__)

  def new(job, fractal_id, points) do
    with {true, _} <- {is_binary(job), "Invalid job name."},
         {true, _} <- {is_binary(fractal_id), "Invalid fractal ID."},
         {true, _} <- {is_integer(points), "Invalid calculated points number."} do
      {:ok, %__MODULE__{job: job, fractal_id: fractal_id, points: points}}
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

  def to_iodata(term) when is_status(term) do
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

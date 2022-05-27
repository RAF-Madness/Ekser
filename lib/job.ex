# Svaki posao ima sledeće atribute:
# ○ Naziv - jedinstveno simboličko ime za ovaj posao. (string)
# ○ N - broj tačaka fraktalne strukture. (int, 3 <= N <= 10)
# ○ P - udaljenost između trenutne tačke i odredišta na kojoj će se pojaviti nova tačka.
# (double u opsegu 0-1)
# ○ W, H - dimenzija površine na kojoj se računaju tačke. (dva int-a)
# ○ A - skup N tačaka. (niz od N parova int-ova

defmodule FractalJob do
  defstruct [:name, :count, :distance, :width, :height, points: []]

  defguardp is_point(term)
            when is_tuple(term) and tuple_size(term) == 2 and
                   is_integer(elem(term, 0)) and is_integer(elem(term, 1)) and
                   elem(term, 0) >= 0 and elem(term, 1) >= 0

  @spec new() :: struct()
  defp new() do
    %__MODULE__{}
  end

  @spec set_name(struct(), String.t()) :: struct()
  defp set_name(fractal_job, name) when is_binary(name) do
    %__MODULE__{fractal_job | name: name}
  end

  defp set_name(_, _) do
    exit("Job name must be a string.")
  end

  @spec set_point_count(struct(), pos_integer()) :: struct()
  defp set_point_count(fractal_job, n) when is_integer(n) and n >= 3 and n <= 10 do
    %__MODULE__{fractal_job | count: n}
  end

  defp set_point_count(_, _) do
    exit("Number of points must be a whole number between 3 and 10 (inclusive).")
  end

  @spec set_point_distance(struct(), float()) :: struct()
  defp set_point_distance(fractal_job, p) when is_float(p) and p >= 0 and p <= 1 do
    %__MODULE__{fractal_job | distance: p}
  end

  defp set_point_distance(_, _) do
    exit("Distance between points must be a floating point number between 0 and 1 (inclusive).")
  end

  @spec set_canvas_resolution(struct(), tuple()) :: struct()
  defp set_canvas_resolution(fractal_job, resolution) when is_point(resolution) do
    {width, height} = resolution
    %__MODULE__{fractal_job | width: width, height: height}
  end

  defp set_canvas_resolution(_, _) do
    exit("Canvas width and height must be positive whole numbers.")
  end

  @spec set_points(struct(), nonempty_list(tuple())) :: struct()
  defp set_points(%__MODULE__{count: n} = fractal_job, points)
       when is_list(points) and length(points) == n do
    is_a_point = fn
      point when is_point(point) -> true
      _ -> false
    end

    if Enum.all?(points, is_a_point) do
      %__MODULE__{fractal_job | points: points}
    else
      exit("Each point in the set of points must consist of 2 positive whole numbers.")
    end
  end

  defp set_points(_, _) do
    exit("Points must be a set of N positive integer pairs.")
  end

  @spec parse_point(String.t(), String.t(), String.t()) :: tuple()
  defp parse_point(string, separator, message)
       when is_binary(string) and is_binary(separator) and is_binary(message) do
    with [string_x, string_y] <- String.split(string, separator),
         {{x, _}, {y, _}} <- {Integer.parse(string_x), Integer.parse(string_y)} do
      {x, y}
    else
      _ -> exit(message)
    end
  end

  @spec parse_count(struct(), String.t()) :: struct()
  defp parse_count(fractal_job, string) when is_binary(string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {n, _} -> set_point_count(fractal_job, n)
      _ -> exit("Failed to parse number of points.")
    end
  end

  @spec parse_distance(struct(), String.t()) :: struct()
  defp parse_distance(fractal_job, string) when is_binary(string) do
    parseResult = Float.parse(string)

    case parseResult do
      {p, _} -> set_point_distance(fractal_job, p)
      _ -> exit("Failed to parse distance between points.")
    end
  end

  @spec parse_resolution(struct(), String.t()) :: struct()
  defp parse_resolution(fractal_job, string) when is_binary(string) do
    parse_point(string, "x", "Failed to parse canvas resolution.")
    |> (&set_canvas_resolution(fractal_job, &1)).()
  end

  @spec parse_points(struct(), String.t()) :: struct()
  defp parse_points(fractal_job, string) do
    string_pairs = String.split(string, "|")

    pairs =
      for string_pair <- string_pairs,
          do: parse_point(string_pair, ",", "Failed to parse points.")

    set_points(fractal_job, pairs)
  end

  @spec create_from_line(String.t()) :: struct()
  def create_from_line(line) do
    [name, count, distance, resolution, points] = String.split(line)

    new()
    |> set_name(name)
    |> parse_count(count)
    |> parse_distance(distance)
    |> parse_resolution(resolution)
    |> parse_points(points)
  end
end

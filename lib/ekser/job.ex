# Svaki posao ima sledeće atribute:
# ○ Naziv - jedinstveno simboličko ime za ovaj posao. (string)
# ○ N - broj tačaka fraktalne strukture. (int, 3 <= N <= 10)
# ○ P - udaljenost između trenutne tačke i odredišta na kojoj će se pojaviti nova tačka.
# (double u opsegu 0-1)
# ○ W, H - dimenzija površine na kojoj se računaju tačke. (dva int-a)
# ○ A - skup N tačaka. (niz od N parova int-ova

defmodule Ekser.Job do
  @behaviour Ekser.Serializable

  @enforce_keys [:name, :count, :distance, :resolution, :points]
  defstruct [:name, :count, :distance, :resolution, :points]

  defguard is_job(term) when is_struct(term, __MODULE__)

  defguardp is_count(term) when is_integer(term) and term >= 3 and term <= 10

  defguardp is_distance(term) when is_float(term) and term >= 0 and term <= 1

  defguardp is_point(term)
            when is_tuple(term) and tuple_size(term) == 2 and
                   is_integer(elem(term, 0)) and is_integer(elem(term, 1)) and
                   elem(term, 0) >= 0 and elem(term, 1) >= 0

  @impl true
  def create_from_json(json) when is_map(json) do
    name = json["name"]
    count = json["pointCount"]
    distance = json["p"]
    resolution = {json["width"], json["height"]}

    points =
      json["mainPoints"]
      |> Enum.map(fn element -> {element["x"], element["y"]} end)

    new(name, count, distance, resolution, points)
  end

  @impl true
  def prepare_for_json(struct) when is_job(struct) do
    %{
      name: struct.name,
      pointCount: struct.count,
      p: struct.distance,
      width: elem(struct.resolution, 0),
      height: elem(struct.resolution, 1),
      mainPoints: Enum.map(struct.mainPoints, fn {x, y} -> %{x: x, y: y} end)
    }
  end

  @spec create_from_line(String.t()) :: tuple()
  def create_from_line(line) when is_binary(line) do
    with [name, count_string, distance_string, resolution_string, points_string] <-
           String.split(line),
         {:ok, count} <- parse_count(count_string),
         {:ok, distance} <- parse_distance(distance_string),
         {:ok, resolution} <- parse_resolution(resolution_string),
         {:ok, points} <- parse_points(points_string) do
      new(name, count, distance, resolution, points)
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Failed to parse job information."}
    end
  end

  defp new(name, count, distance, resolution, points) do
    with {true, _} <- {is_binary(name), "Job name must be a string."},
         {true, _} <-
           {is_count(count), "Job point count must be an integer between 3 and 10 (inclusive)."},
         {true, _} <-
           {is_distance(distance),
            "Job point distance must be a floating point number between 0 and 1 (inclusive)."},
         {true, _} <-
           {is_point(resolution),
            "Job canvas resolution must be a pair of integers denoting width and height."},
         {:ok, points} <- check_points(points) do
      %__MODULE__{
        name: name,
        count: count,
        distance: distance,
        resolution: resolution,
        points: points
      }
    else
      {false, message} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end

  defp check_points(points) do
    with {true, _} <- {is_list(points), "Not a valid list of points."},
         {true, _} <-
           {
             Enum.all?(points, fn element -> is_point(element) end),
             "Each point in the set of points must consist of 2 positive integers."
           } do
      {:ok, points}
    else
      {false, message} -> {:error, message}
    end
  end

  @spec find_job(list(%__MODULE__{}), String.t()) :: any()
  def find_job(jobs, job_name) when is_list(jobs) and is_binary(job_name) do
    Enum.find(jobs, fn element -> element.name === job_name end)
  end

  defp parse_point(string, separator)
       when is_binary(string) and is_binary(separator) do
    with [string_x, string_y] <- String.split(string, separator),
         {{x, _}, {y, _}} <- {Integer.parse(string_x), Integer.parse(string_y)} do
      {x, y}
    else
      _ -> :error
    end
  end

  defp parse_count(string) when is_binary(string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {n, _} -> {:ok, n}
      _ -> {:error, "Failed to parse number of points."}
    end
  end

  defp parse_distance(string) when is_binary(string) do
    parseResult = Float.parse(string)

    case parseResult do
      {p, _} -> {:ok, p}
      _ -> {:error, "Failed to parse distance between points."}
    end
  end

  defp parse_resolution(string) when is_binary(string) do
    parseResult = parse_point(string, "x")

    case parseResult do
      {x, y} -> {:ok, {x, y}}
      :error -> {:error, "Failed to parse canvas resolution."}
    end
  end

  defp parse_points(string) do
    string_pairs = String.split(string, "|")

    points = for string_pair <- string_pairs, do: parse_point(string_pair, ",")

    case Enum.any?(points, fn element -> element === :error end) do
      true -> {:error, "Failed to parse points."}
      false -> {:ok, points}
    end
  end
end

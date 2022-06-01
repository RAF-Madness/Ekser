# Svaki posao ima sledeće atribute:
# ○ Naziv - jedinstveno simboličko ime za ovaj posao. (string)
# ○ N - broj tačaka fraktalne strukture. (int, 3 <= N <= 10)
# ○ P - udaljenost između trenutne tačke i odredišta na kojoj će se pojaviti nova tačka.
# (double u opsegu 0-1)
# ○ W, H - dimenzija površine na kojoj se računaju tačke. (dva int-a)
# ○ A - skup N tačaka. (niz od N parova int-ova

defmodule Job do
  defstruct [:name, :count, :distance, :resolution, points: []]

  defguard is_job(term) when is_struct(term, __MODULE__)

  @spec create_from_line(String.t()) :: tuple()
  def create_from_line(line) when is_binary(line) do
    with [name, count_string, distance_string, resolution_string, points_string] <-
           String.split(line),
         {:ok, count} <- parse_count(count_string),
         {:ok, distance} <- parse_distance(distance_string),
         {:ok, resolution} <- parse_resolution(resolution_string),
         {:ok, points} <- parse_points(points_string) do
      create(name, count, distance, resolution, points)
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Failed to parse job information."}
    end
  end

  @spec create_from_map(map) ::
          {:ok,
           %Job{
             count: 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10,
             distance: float,
             name: binary,
             points: list,
             resolution: {any, any}
           }}
  def create_from_map(map) when is_map(map) do
    name = map["name"]
    count = map["pointCount"]
    distance = map["p"]
    resolution = {map["width"], map["height"]}
    points = map["mainPoints"]

    create(name, count, distance, resolution, points)
  end

  @spec find_job(list(struct()), String.t()) :: any()
  def find_job(job_list, job_name) when is_list(job_list) and is_binary(job_name) do
    Enum.find(job_list, fn element -> element.name === job_name end)
  end

  @spec duplicate_jobs?(list(struct())) :: boolean()
  def duplicate_jobs?(job_list) when is_list(job_list) do
    unique =
      Enum.reduce_while(job_list, [], fn element, acc ->
        case element.name in acc do
          true -> {:cont, [element.name | acc]}
          false -> {:halt, acc}
        end
      end)

    length(unique) === length(job_list)
  end

  @spec job_exists?(list(struct()), struct()) :: boolean()
  def job_exists?(job_list, job) when is_list(job_list) and is_struct(job, __MODULE__) do
    Enum.any?(job_list, fn element ->
      element.name === job.name
    end)
  end

  defguardp is_count(term) when is_integer(term) and term >= 3 and term <= 10

  defguardp is_distance(term) when is_float(term) and term >= 0 and term <= 1

  defguardp is_point(term)
            when is_tuple(term) and tuple_size(term) == 2 and
                   is_integer(elem(term, 0)) and is_integer(elem(term, 1)) and
                   elem(term, 0) >= 0 and elem(term, 1) >= 0

  defp new(name) when is_binary(name) do
    %__MODULE__{name: name}
  end

  defp set_point_count(job, n) when is_job(job) and is_count(n) do
    {:ok, %__MODULE__{job | count: n}}
  end

  defp set_point_count(_, _) do
    {:error, "Number of points must be a whole number between 3 and 10 (inclusive)."}
  end

  defp set_point_distance(job, p) when is_job(job) and is_distance(p) do
    {:ok, %__MODULE__{job | distance: p}}
  end

  defp set_point_distance(_, _) do
    {:error,
     "Distance between points must be a floating point number between 0 and 1 (inclusive)."}
  end

  defp set_canvas_resolution(job, resolution) when is_job(job) and is_point(resolution) do
    {:ok, %__MODULE__{job | resolution: resolution}}
  end

  defp set_canvas_resolution(_, _) do
    {:error, "Canvas width and height must be positive whole numbers."}
  end

  defp set_main_points(%__MODULE__{count: n} = job, points)
       when is_job(job) and is_list(points) and length(points) == n do
    if Enum.all?(points, fn element -> is_point(element) end) do
      {:ok, %__MODULE__{job | points: points}}
    else
      {:error, "Each point in the set of points must consist of 2 positive whole numbers."}
    end
  end

  defp set_main_points(_, _) do
    {:error, "Points must be a set of N positive integer pairs."}
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

  defp create(name, count, distance, resolution, points) do
    base = new(name)

    with {:ok, counted} <- set_point_count(base, count),
         {:ok, distanced} <- set_point_distance(counted, distance),
         {:ok, resolutioned} <- set_canvas_resolution(distanced, resolution),
         {:ok, pointed} <- set_main_points(resolutioned, points) do
      {:ok, pointed}
    else
      {:error, message} -> {:error, message}
    end
  end
end

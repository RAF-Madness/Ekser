defmodule Ekser.Point do
  @type point() :: {pos_integer(), pos_integer()}

  defguard is_point(term)
           when is_tuple(term) and tuple_size(term) == 2 and
                  is_integer(elem(term, 0)) and is_integer(elem(term, 1)) and
                  elem(term, 0) >= 0 and elem(term, 1) >= 0

  @spec valid_points?(list(point())) :: boolean()
  def valid_points?(points) do
    is_list(points) and Enum.all?(points, fn element -> is_point(element) end)
  end

  @spec parse_point(String.t(), String.t()) :: point() | :error
  def parse_point(string, separator)
      when is_binary(string) and is_binary(separator) do
    with [string_x, string_y] <- String.split(string, separator),
         {{x, _}, {y, _}} <- {Integer.parse(string_x), Integer.parse(string_y)} do
      {x, y}
    else
      _ -> :error
    end
  end

  @spec from_json(list(map())) :: list(point())
  def from_json(list) do
    with true <- is_list(list),
         stream <- Stream.map(list, fn element -> {element["x"], element["y"]} end),
         nil <- Enum.find(stream, fn {x, y} -> x === nil or y === nil end) do
      Enum.to_list(stream)
    else
      _ -> :error
    end
  end

  @spec to_json(list(point())) :: list(map())
  def to_json(list) do
    Enum.map(list, fn {x, y} -> %{x: x, y: y} end)
  end

  @spec scale_to_fractal_id(float(), String.t(), {list(point()), list(point())}) ::
          {list(point()), list(point())}
  def scale_to_fractal_id(ratio, fractal_id, {anchor_points, points}) do
    digits = Ekser.FractalId.get_digits(fractal_id)

    Enum.reduce(digits, {anchor_points, points}, fn anchor_index, {anchor_points, points} ->
      anchor = Enum.at(anchor_points, anchor_index)
      {scale_points(ratio, anchor, anchor_points), scale_points(ratio, anchor, points)}
    end)
  end

  @spec next_point(float(), list(point()), point()) :: point()
  def next_point(ratio, anchor_points, last_point) do
    scale_point(ratio, Enum.random(anchor_points), last_point)
  end

  defp scale_points(ratio, anchor_point, points) do
    Stream.map(points, fn point -> scale_point(ratio, anchor_point, point) end)
  end

  defp scale_point(ratio, {anchor_x, anchor_y}, {x, y}) do
    {scale_coordinate(ratio, anchor_x, x), scale_coordinate(ratio, anchor_y, y)}
  end

  defp scale_coordinate(ratio, anchor_coordinate, coordinate) do
    round(coordinate * ratio + (1 - ratio) * anchor_coordinate)
  end
end

defmodule Ekser.Point do
  defguard is_point(term)
           when is_tuple(term) and tuple_size(term) == 2 and
                  is_integer(elem(term, 0)) and is_integer(elem(term, 1)) and
                  elem(term, 0) >= 0 and elem(term, 1) >= 0

  @spec valid_points?(list(tuple())) :: boolean()
  def valid_points?(points) do
    is_list(points) and Enum.all?(points, fn element -> is_point(element) end)
  end

  @spec parse_point(String.t(), String.t()) :: tuple() | :error
  def parse_point(string, separator)
      when is_binary(string) and is_binary(separator) do
    with [string_x, string_y] <- String.split(string, separator),
         {{x, _}, {y, _}} <- {Integer.parse(string_x), Integer.parse(string_y)} do
      {x, y}
    else
      _ -> :error
    end
  end

  @spec from_json(list(map())) :: list(tuple())
  def from_json(list) do
    with true <- is_list(list),
         stream <- Stream.map(list, fn element -> {element["x"], element["y"]} end),
         nil <- Enum.find(stream, fn {x, y} -> x === nil or y === nil end) do
      Enum.to_list(stream)
    else
      _ -> :error
    end
  end

  @spec to_json(list(tuple())) :: list(map())
  def to_json(list) do
    Enum.map(list, fn {x, y} -> %{x: x, y: y} end)
  end

  def next_point(anchor_points, last_point, scale) do
    last_point
    |> scale_coordinate(Enum.random(anchor_points), scale)
  end

  def scale_point({x, y}, {reference_x, reference_y}, scale) do
    {scale_coordinate(x, reference_x, scale), scale_coordinate(y, reference_y, scale)}
  end

  defp scale_coordinate(coordinate, reference_coordinate, scale) do
    round(coordinate * scale + (1 - scale) * reference_coordinate)
  end
end

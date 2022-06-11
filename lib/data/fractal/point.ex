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
end

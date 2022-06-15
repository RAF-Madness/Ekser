defmodule Ekser.FractalId do
  def get_next(fractal_id, point_count) do
    {base_rep, _} = Integer.parse(fractal_id, point_count)
    new_base_rep = base_rep + 1

    string = String.to_integer(base_rep, point_count)
    new_string = String.to_integer(new_base_rep, point_count)

    case String.length(string) === String.length(new_string) do
      true -> String.pad_leading(new_string, String.length(fractal_id), "0")
      false -> String.pad_leading(new_string, String.length(fractal_id) + 1, "0")
    end
  end

  def is_child?(fractal_id, other) do
    list_id = String.graphemes(fractal_id)

    removed_tail =
      list_id
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()

    list_other = String.graphemes(other)

    with true <- length(list_other) > 0 do
      (length(list_id) === length(list_other) and length(list_id) === 1) or
        removed_tail === list_other
    else
      false -> false
    end
  end

  def compare_edit_distance(fractal_id, other, value) do
    length = max(String.length(fractal_id), String.length(other))

    padded_id =
      String.pad_trailing(fractal_id, length, ["0"])
      |> String.graphemes()

    padded_other =
      String.pad_trailing(other, length, ["0"])
      |> String.graphemes()

    Stream.zip(padded_id, padded_other)
    |> Enum.reduce_while(0, fn element, acc -> calculate_edit_distance(element, acc, value) end)
  end

  def valid_fractal_id?(fractal_id) do
    with true <- is_binary(fractal_id),
         true <- is_number?(fractal_id) do
      true
    else
      _ -> false
    end
  end

  def get_digits(fractal_id) do
    fractal_id
    |> String.graphemes()
    |> Enum.map(fn digit -> String.to_integer(digit) end)
  end

  defp calculate_edit_distance({char1, char2}, acc, value) do
    cond do
      char1 === char2 and acc === value ->
        {:halt, false}

      char1 === char2 ->
        {:cont, acc + 1}

      true ->
        {:cont, acc}
    end
  end

  defp is_number?(fractal_id) do
    case Integer.parse(fractal_id) do
      :error -> false
      {_, leftover} -> String.trim(leftover) === ""
    end
  end
end

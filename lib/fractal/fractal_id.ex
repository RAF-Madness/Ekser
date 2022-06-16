defmodule Ekser.FractalId do
  def get_next(fractal_id, point_count) do
    # {base_rep, _} = Integer.parse(fractal_id, point_count)
    base_rep = String.to_integer(fractal_id, point_count)
    new_base_rep = base_rep + 1

    new_string = Integer.to_string(new_base_rep, point_count)

    # If the last digit is 0 (cascading), add 1
    [last_digit | _] = new_string |> String.graphemes() |> Enum.reverse()

    newer_string =
      case last_digit === "0" do
        true -> Integer.to_string(new_base_rep + 1, point_count)
        false -> new_string
      end

    # If the value overflows, replace the first part with 0

    overflow? = String.length(newer_string) > String.length(fractal_id)

    case overflow? do
      true ->
        dropped = newer_string |> Enum.drop(1)
        ["0" | dropped]

      false ->
        String.pad_leading(newer_string, String.length(fractal_id), "0")
    end
  end

  def is_child?(fractal_id, other) do
    list_id = String.graphemes(fractal_id)

    list_other = String.graphemes(other)

    removed_tail =
      list_other
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()

    with true <- length(list_id) > 0 do
      (fractal_id === "0" and length(list_other) === 0) or
        removed_tail === list_id
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
    with true <- is_binary(fractal_id) do
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
end

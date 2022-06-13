defmodule Ekser.Command do
  require Ekser.Job

  @enforce_keys [:name, :function, :parameters, :format]
  defstruct [
    :name,
    :function,
    :parameters,
    :format
  ]

  def new(name, function, parameters, format) do
    %__MODULE__{name: name, function: function, parameters: parameters, format: format}
  end

  @spec execute(%__MODULE__{}, list(String.t()), any()) ::
          String.t() | {String.t(), function()} | {%Ekser.Job{}, function()}
  def execute(command, arguments, output) do
    command.function.(arguments, output)
  end

  @spec resolve_command(nonempty_list(String.t()), any()) ::
          {:ok, %__MODULE__{}, list()} | {:error, String.t()}
  def resolve_command([user_command | rest], output) do
    case Enum.find(generate_commands(), fn command -> command.name === user_command end) do
      nil ->
        {:error, "Invalid command."}

      command ->
        parse_args(command, rest, output)
    end
  end

  def resolve_job_name(arg, _) when is_binary(arg) do
    found = Ekser.JobStore.job_exists?(arg)

    case found do
      false -> {:error, "Failed to find job called #{arg}."}
      true -> arg
    end
  end

  def resolve_id(arg, _) when is_binary(arg) do
    arg
  end

  def resolve_milliseconds(arg, _) when is_binary(arg) do
    with {milliseconds, _} <- Integer.parse(arg),
         true <- milliseconds > 0 do
      milliseconds
    else
      false -> {:error, "Amount of milliseconds to pause must be a positive integer."}
      :error -> {:error, "Couldn't parse amount of milliseconds to pause."}
    end
  end

  def resolve_output(_, output) do
    output
  end

  @callback generate() :: %__MODULE__{
              name: String.t(),
              function: function(),
              parameters: list(),
              format: String.t()
            }

  defp generate_commands() do
    [
      Ekser.Command.Status.generate(),
      Ekser.Command.Start.generate(),
      Ekser.Command.Result.generate(),
      Ekser.Command.Stop.generate(),
      Ekser.Command.Pause.generate(),
      Ekser.Command.Quit.generate()
    ]
  end

  defp parse_args(command, args, output) do
    params = command.parameters
    param_amount = length(params)
    arg_amount = length(args)

    with {true, _} <-
           {arg_amount <= param_amount, "Too many arguments given. " <> command.format},
         {true, _} <-
           {arg_amount === param_amount or
              elem(Enum.at(params, max(0, arg_amount - 1)), 1),
            "Not enough arguments given. " <> command.format} do
      resolve_args(params, args, output)
    else
      {false, message} ->
        {:error, message}
    end
  end

  defp resolve_args(parameters, args, output) do
    resolved_arguments =
      Stream.zip_with(parameters, args, fn {param_func, _}, arg ->
        param_func.(arg, output)
      end)

    error_resolving =
      Enum.find(resolved_arguments, fn
        {:error, _} -> true
        _ -> false
      end)

    case error_resolving do
      nil -> {:ok, resolved_arguments |> Enum.to_list()}
      error -> error
    end
  end
end

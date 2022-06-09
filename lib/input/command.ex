defmodule Ekser.Command do
  require Ekser.Job

  @enforce_keys [:name, :function, :parameters, :format]
  defstruct [
    :name,
    :function,
    :parameters,
    :format
  ]

  @spec execute(%__MODULE__{}, list()) ::
          String.t() | {String.t(), function()} | {String.t(), function(), %Ekser.Job{}}
  def execute(command, arguments) do
    command.function.(arguments)
  end

  @spec get_command(nonempty_list(String.t()), nonempty_list(%Ekser.Job{})) ::
          {:ok, %__MODULE__{}, list()} | {:error, String.t()}
  def get_command([user_command | rest], jobs) do
    with {:ok, command} <-
           find_command_spec(user_command, generate_commands()),
         {:ok, arguments} <- get_args(command.parameters, rest, jobs, command.format) do
      {:ok, command, arguments}
    else
      {:error, message} -> {:error, message}
    end
  end

  def new(name, function, parameters, format) do
    %__MODULE__{name: name, function: function, parameters: parameters, format: format}
  end

  def resolve_job(arg, jobs) when is_binary(arg) do
    selected_job = Ekser.Job.find_job(jobs, arg)

    case selected_job do
      nil -> {:error, "Failed to find job with name " <> arg <> "."}
      job -> job
    end
  end

  def resolve_id(arg, _) when is_binary(arg) do
    parse_result = Integer.parse(arg)

    case parse_result do
      {id, _} -> id
      _ -> {:error, "Couldn't parse node ID."}
    end

    # DHT.check_id()
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

  defp find_command_spec(user_command, commands) do
    command = Enum.find(commands, nil, fn command -> command.name === user_command end)

    case command do
      nil ->
        {:error, "Invalid command."}

      command ->
        {:ok, command}
    end
  end

  defp get_args(parameters, args, jobs, format) do
    with arg_amount <- length(args),
         {_, true} <- {"length", arg_amount <= length(parameters)},
         {_, true} <-
           {"optional",
            arg_amount == length(parameters) or
              elem(Enum.at(parameters, max(0, arg_amount - 1)), 1)},
         {:ok, resolved} <- resolve_args(parameters, args, jobs) do
      {:ok, resolved}
    else
      {"length", false} ->
        {:error, "Too many arguments given. " <> format}

      {"optional", false} ->
        {:error, "Not enough arguments given. " <> format}

      {:error, message} ->
        {:error, message <> " " <> format}
    end
  end

  defp resolve_args(parameters, args, jobs) do
    resolved_arguments =
      Stream.zip_with(parameters, args, fn {param_func, _}, arg ->
        param_func.(arg, jobs)
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

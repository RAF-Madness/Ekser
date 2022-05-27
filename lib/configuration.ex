# ● Port na kojem će čvor da sluša. (short)
# ● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
# ● Slaba granica otkaza - odeljak 3.2. (int)
# ● Jaka granica otkaza - odeljak 3.2. (int)
# ● Skup predefinisanih poslova.

defmodule Configuration do
  defstruct [
    :port,
    :bootstrap,
    :watchdog_timeout,
    :failure_timeout,
    job_list: []
  ]

  defguardp is_tcp_port(term) when is_integer(term) and term > 0 and term <= 65535

  @spec new() :: struct()
  defp new() do
    %__MODULE__{}
  end

  @spec set_port(struct(), pos_integer()) :: struct()
  defp set_port(config, port) when is_tcp_port(port) do
    %__MODULE__{config | port: port}
  end

  defp set_port(_, _) do
    exit("Port must be a positive whole number between 1 and 65535 (inclusive).")
  end

  @spec set_bootstrap(struct(), tuple()) :: struct()
  defp set_bootstrap(config, {ip, port} = bootstrap) when is_binary(ip) and is_tcp_port(port) do
    %__MODULE__{config | bootstrap: bootstrap}
  end

  defp set_bootstrap(_, _) do
    exit("Port must be a positive whole number between 1 and 65535 (inclusive).")
  end

  @spec set_watchdog(struct(), pos_integer()) :: struct()
  defp set_watchdog(config, timeout) when is_integer(timeout) and timeout > 0 do
    %__MODULE__{config | watchdog_timeout: timeout}
  end

  defp set_watchdog(_, _) do
    exit("Watchdog timeout must be a positive whole number.")
  end

  @spec set_failure(struct(), pos_integer()) :: struct()
  defp set_failure(config, timeout) when is_integer(timeout) and timeout > 0 do
    %__MODULE__{config | failure_timeout: timeout}
  end

  defp set_failure(_, _) do
    exit("Failure timeout must be a positive whole number.")
  end

  @spec add_job(struct(), struct()) :: struct()
  defp add_job(config, job) do
    %__MODULE__{config | job_list: [job | config.job_list]}
  end

  @spec set_field(tuple(), struct()) :: struct()
  defp set_field(value, config) do
    case value do
      {:port, port} -> set_port(config, port)
      {:bootstrap, bootstrap} -> set_bootstrap(config, bootstrap)
      {:watchdog_timeout, timeout} -> set_watchdog(config, timeout)
      {:failure_timeout, timeout} -> set_failure(config, timeout)
      {:job, job} -> add_job(config, job)
      _ -> exit("Failed to set field.")
    end
  end

  @spec parse_port(String.t()) :: pos_integer()
  defp parse_port(string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {port, _} -> port
      _ -> exit("Failed to parse port.")
    end
  end

  @spec parse_bootstrap(String.t()) :: tuple()
  defp parse_bootstrap(string) do
    with [ip, portString] <- String.split(string, ":"),
         {port, _} <- Integer.parse(portString) do
      {ip, port}
    else
      _ -> exit("Failed to parse bootstrap information.")
    end
  end

  @spec parse_watchdog(String.t()) :: pos_integer()
  defp parse_watchdog(string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {timeout, _} -> timeout
      _ -> exit("Failed to parse watchdog timeout.")
    end
  end

  @spec parse_failure(String.t()) :: pos_integer()
  defp parse_failure(string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {timeout, _} -> timeout
      _ -> exit("Failed to parse failure timeout.")
    end
  end

  @spec parse_job(String.t()) :: struct()
  defp parse_job(line) do
    FractalJob.create_from_line(line)
  end

  @spec parse_line(String.t()) :: tuple()
  defp parse_line(line) do
    case line do
      "port=" <> rest -> {:port, parse_port(rest)}
      "bootstrap=" <> rest -> {:bootstrap, parse_bootstrap(rest)}
      "watchdog=" <> rest -> {:watchdog_timeout, parse_watchdog(rest)}
      "failure=" <> rest -> {:failure_timeout, parse_failure(rest)}
      line -> {:job, parse_job(line)}
    end
  end

  @spec read_config(String.t()) :: struct()
  def read_config(file) do
    # file_path = String.replace(file, "\\", "//")

    config =
      File.stream!(file)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&parse_line/1)
      |> Enum.reduce(new(), &set_field/2)

    config
  end
end

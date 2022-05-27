# ● Port na kojem će čvor da sluša. (short)
# ● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
# ● Slaba granica otkaza - odeljak 3.2. (int)
# ● Jaka granica otkaza - odeljak 3.2. (int)
# ● Skup predefinisanih poslova.

defmodule Configuration do
  defstruct [
    :port,
    :bootstrap_ip,
    :bootstrap_port,
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

  @spec set_bootstrap(struct(), String.t(), pos_integer()) :: struct()
  defp set_bootstrap(config, ip, port) when is_tcp_port(port) do
    %__MODULE__{config | bootstrap_ip: ip, bootstrap_port: port}
  end

  defp set_bootstrap(_, _, _) do
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

  @spec parse_port(struct(), String.t()) :: struct()
  defp parse_port(config, string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {port, _} -> set_port(config, port)
      _ -> exit("Failed to parse port.")
    end
  end

  @spec parse_bootstrap(struct(), String.t()) :: struct()
  defp parse_bootstrap(config, string) do
    with [ip, portString] <- String.split(string, ":"),
         port <- Integer.parse(portString) do
      set_bootstrap(config, ip, port)
    else
      _ -> exit("Failed to parse bootstrap information.")
    end
  end

  @spec parse_watchdog(struct(), String.t()) :: struct()
  defp parse_watchdog(config, string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {timeout, _} -> set_watchdog(config, timeout)
      _ -> exit("Failed to parse watchdog timeout.")
    end
  end

  @spec parse_failure(struct(), String.t()) :: struct()
  defp parse_failure(config, string) do
    parseResult = Integer.parse(string)

    case parseResult do
      {timeout, _} -> set_failure(config, timeout)
      _ -> exit("Failed to parse failure timeout.")
    end
  end

  @spec parse_job(struct(), String.t()) :: struct()
  defp parse_job(config, line) do
    job = FractalJob.create_from_line(line)
    %__MODULE__{config | job_list: [job | config.job_list]}
  end

  @spec parse_job(struct(), String.t()) :: struct()
  defp parse_line(config, line) do
    case line do
      "port=" <> rest -> parse_port(config, rest)
      "bootstrap=" <> rest -> parse_bootstrap(config, rest)
      "watchdog=" <> rest -> parse_watchdog(config, rest)
      "failure=" <> rest -> parse_failure(config, rest)
      line -> parse_job(config, line)
    end
  end

  def read_config(file) do
    _config =
      File.stream!(file)
      |> Enum.map(&String.trim/1)
  end
end

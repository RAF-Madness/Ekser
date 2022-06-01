# ● Port na kojem će čvor da sluša. (short)
# ● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
# ● Slaba granica otkaza - odeljak 3.2. (int)
# ● Jaka granica otkaza - odeljak 3.2. (int)
# ● Skup predefinisanih poslova.

defmodule Configuration do
  require Job

  defstruct [
    :port,
    :bootstrap,
    :watchdog_timeout,
    :failure_timeout,
    job_list: []
  ]

  defguard is_config(term) when is_struct(term, __MODULE__)

  defguardp is_tcp_port(term) when is_integer(term) and term > 0 and term <= 65535

  defguardp is_bootstrap(term)
            when is_tuple(term) and is_binary(elem(term, 0)) and is_tcp_port(elem(term, 1))

  defguardp is_timeout(term) when is_integer(term) and term > 0

  def read_config(file) do
    response =
      File.read!(file)
      |> Jason.decode!()
      |> create_from_map

    case response do
      {:ok, config} -> config
      {:error, message} -> exit(message)
    end
  end

  defp new() do
    %__MODULE__{}
  end

  defp set_port(config, port) when is_config(config) and is_tcp_port(port) do
    {:ok, %__MODULE__{config | port: port}}
  end

  defp set_port(_, _) do
    {:error, "Port must be a positive whole number between 1 and 65535 (inclusive)."}
  end

  defp set_bootstrap(config, bootstrap)
       when is_config(config) and is_bootstrap(bootstrap) do
    {:ok, %__MODULE__{config | bootstrap: bootstrap}}
  end

  defp set_bootstrap(_, _) do
    {:error, "Bootstrap must be an IP address and a port separated by a colon."}
  end

  defp set_watchdog(config, timeout) when is_config(config) and is_timeout(timeout) do
    {:ok, %__MODULE__{config | watchdog_timeout: timeout}}
  end

  defp set_watchdog(_, _) do
    {:error, "Watchdog timeout must be a positive whole number."}
  end

  defp set_failure(config, timeout) when is_config(config) and is_timeout(timeout) do
    {:ok, %__MODULE__{config | failure_timeout: timeout}}
  end

  defp set_failure(_, _) do
    {:error, "Failure timeout must be a positive whole number."}
  end

  defp set_jobs(config, job_list) when is_config(config) and is_list(job_list) do
    case Enum.all?(job_list, fn element -> Job.is_job(element) end) do
      true -> {:ok, %__MODULE__{config | job_list: job_list}}
      false -> {:error, "Job list must contain only jobs."}
    end
  end

  defp create_from_map(map) when is_map(map) do
    port = map["port"]
    bootstrap = {map["bootstrap_ip"], map["bootstrap_port"]}
    watchdog_timeout = map["weakLimit"]
    failure_timeout = map["strongLimit"]
    jobs = map["jobs"] |> to_jobs()

    case jobs do
      {:ok, job_list} -> create(port, bootstrap, watchdog_timeout, failure_timeout, job_list)
      {:error, message} -> {:error, message}
    end
  end

  defp to_jobs(map_list) when is_list(map_list) do
    job_list = for map <- map_list, do: Job.create_from_map(map)

    case Enum.all?(job_list, fn
           {:ok, _} -> true
           {:error, _} -> false
         end) do
      true -> {:ok, job_list}
      false -> {:error, "Failed to parse jobs."}
    end
  end

  defp create(port, bootstrap, watchdog, failure, jobs) do
    base = new()

    with {:ok, ported} <- set_port(base, port),
         {:ok, bootstraped} <- set_bootstrap(ported, bootstrap),
         {:ok, watchdogged} <- set_watchdog(bootstraped, watchdog),
         {:ok, failured} <- set_failure(watchdogged, failure),
         {:ok, jobbed} <- set_jobs(failured, jobs) do
      {:ok, jobbed}
    else
      {:error, message} -> {:error, message}
    end
  end
end

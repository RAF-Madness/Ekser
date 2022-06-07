# ● Port na kojem će čvor da sluša. (short)
# ● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
# ● Slaba granica otkaza - odeljak 3.2. (int)
# ● Jaka granica otkaza - odeljak 3.2. (int)
# ● Skup predefinisanih poslova.

defmodule Ekser.Config do
  require Ekser.Util
  require Ekser.Job

  defstruct [
    :port,
    :bootstrap,
    :watchdog_timeout,
    :failure_timeout,
    jobs: []
  ]

  defguard is_config(term) when is_struct(term, __MODULE__)

  defguardp is_timeout(term) when is_integer(term) and term > 0

  @spec read_config(String.t()) :: struct()
  def read_config(file) do
    response =
      Path.expand(file)
      |> File.read!()
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

  defp set_port(config, port) when is_config(config) and Ekser.Util.is_tcp_port(port) do
    {:ok, %__MODULE__{config | port: port}}
  end

  defp set_port(_, _) do
    {:error, Ekser.Util.port_prompt()}
  end

  defp set_bootstrap(config, bootstrap)
       when is_config(config) and Ekser.Util.is_tcp_address(bootstrap) do
    {:ok, %__MODULE__{config | bootstrap: bootstrap}}
  end

  defp set_bootstrap(_, _) do
    {:error, "Bootstrap must be an IP address and a port."}
  end

  defp set_watchdog(config, timeout) when is_config(config) and is_timeout(timeout) do
    {:ok, %__MODULE__{config | watchdog_timeout: timeout}}
  end

  defp set_watchdog(_, _) do
    {:error, "Watchdog timeout must be a positive integer."}
  end

  defp set_failure(config, timeout) when is_config(config) and is_timeout(timeout) do
    {:ok, %__MODULE__{config | failure_timeout: timeout}}
  end

  defp set_failure(_, _) do
    {:error, "Failure timeout must be a positive integer."}
  end

  defp set_jobs(config, jobs) when is_config(config) and is_list(jobs) do
    with {_, true} <- {"jobs", Enum.all?(jobs, fn element -> Ekser.Job.is_job(element) end)},
         unique_jobs <- Enum.uniq_by(jobs, fn element -> element.name end),
         {_, true} <- {"unique", length(unique_jobs) === length(jobs)} do
      {:ok, %__MODULE__{config | jobs: jobs}}
    else
      {"jobs", false} -> {:error, "Job list must contain jobs only."}
      {"unique", false} -> {:error, "Job list cannot contain 2 or more jobs with the same name."}
    end
  end

  defp set_jobs(_, _) do
    {:error, "Job list must be a valid list of uniquely named jobs."}
  end

  defp create_from_map(map) when is_map(map) do
    port = map["port"]
    watchdog_timeout = map["weakLimit"]
    failure_timeout = map["strongLimit"]

    with {:ok, bootstrap} <-
           Ekser.Util.to_address(map["bootstrapIpAddress"], map["bootstrapPort"]),
         {:ok, jobs} <- map["jobs"] |> to_jobs() do
      create(port, bootstrap, watchdog_timeout, failure_timeout, jobs)
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Failed to parse configuration."}
    end
  end

  defp to_jobs(map_list) when is_list(map_list) do
    jobs = for map <- map_list, do: Ekser.Job.create_from_map(map)

    error_reading =
      Enum.find(jobs, fn
        {:error, _} -> true
        _ -> false
      end)

    case error_reading do
      nil -> {:ok, Enum.map(jobs, fn {:ok, job} -> job end)}
      {:error, message} -> {:error, message}
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

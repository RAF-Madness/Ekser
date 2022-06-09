# ● Port na kojem će čvor da sluša. (short)
# ● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
# ● Slaba granica otkaza - odeljak 3.2. (int)
# ● Jaka granica otkaza - odeljak 3.2. (int)
# ● Skup predefinisanih poslova.

defmodule Ekser.Config do
  require Ekser.Util
  require Ekser.Node
  require Ekser.Job
  @behaviour Ekser.Serializable

  @enforce_keys [:port, :bootstrap, :weak_timeout, :strong_timeout, :jobs]
  defstruct [
    :port,
    :bootstrap,
    :weak_timeout,
    :strong_timeout,
    :jobs
  ]

  defguard is_config(term) when is_struct(term, __MODULE__)

  defguardp is_timeout(term) when is_integer(term) and term > 0

  @spec read_config(String.t()) :: struct()
  def read_config(file) do
    response =
      Path.expand(file)
      |> File.read!()
      |> Jason.decode!()
      |> create_from_json()

    case response do
      {:ok, config} -> config
      {:error, message} -> exit(message)
    end
  end

  @impl true
  def create_from_json(json) when is_map(json) do
    port = json["port"]
    weak_timeout = json["weakLimit"]
    strong_timeout = json["strongLimit"]

    with {:ok, ip} <- Ekser.Util.to_ip(json["bootstrapIpAddress"]),
         {:ok, bootstrap} <- Ekser.Node.new(-1, ip, json["bootstrapPort"]),
         {:ok, jobs} <- json["jobs"] |> to_jobs() do
      new(port, bootstrap, weak_timeout, strong_timeout, jobs)
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Failed to parse configuration."}
    end
  end

  @impl true
  def prepare_for_json(struct) when is_config(struct) do
    %{
      port: struct.port,
      bootstrapIpAddress: Ekser.Util.from_ip(struct.bootstrap.ip),
      bootstrapPort: struct.bootstrap.port,
      weakLimit: struct.watchdog_timeout,
      strongLimit: struct.failure_timeout,
      jobs: Enum.map(struct.jobs, fn job -> Ekser.Job.prepare_for_json(job) end)
    }
  end

  defp new(port, bootstrap, weak_timeout, strong_timeout, jobs) do
    with {true, _} <-
           {Ekser.Util.is_tcp_port(port), Ekser.Util.port_prompt()},
         {true, _} <-
           {Ekser.Node.is_node(bootstrap),
            "Bootstrap must be in the form of a node (tuple with id, IP and port)."},
         {true, _} <- {is_timeout(weak_timeout), "Weak timeout must be a positive integer."},
         {true, _} <- {is_timeout(strong_timeout), "Strong timeout must be a positive integer."},
         {:ok, jobs} <- check_jobs(jobs) do
      {:ok,
       %__MODULE__{
         port: port,
         bootstrap: bootstrap,
         weak_timeout: weak_timeout,
         strong_timeout: strong_timeout,
         jobs: jobs
       }}
    else
      {false, message} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end

  defp check_jobs(jobs) do
    with {true, _} <- {is_list(jobs), "Not a valid job list."},
         {true, _} <-
           {Enum.all?(jobs, fn element -> Ekser.Job.is_job(element) end), "Not a valid job list."},
         {true, _} <-
           {length(Enum.uniq_by(jobs, fn element -> element.name end)) === length(jobs),
            "Job list cannot contain more than one job with the same name."} do
      {:ok, jobs}
    else
      {false, message} -> {:error, message}
    end
  end

  defp to_jobs(map_list) when is_list(map_list) do
    jobs = for map <- map_list, do: Ekser.Job.create_from_json(map)

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
end
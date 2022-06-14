# ● Port na kojem će čvor da sluša. (short)
# ● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
# ● Slaba granica otkaza - odeljak 3.2. (int)
# ● Jaka granica otkaza - odeljak 3.2. (int)
# ● Skup predefinisanih poslova.

defmodule Ekser.Config do
  require Ekser.TCP
  require Ekser.Job
  require Ekser.Node
  @behaviour Ekser.Serializable

  @enforce_keys [:port, :bootstrap, :weak_timeout, :strong_timeout, :jobs]
  defstruct @enforce_keys

  defguardp is_timeout(term) when is_integer(term) and term > 0

  @spec read_config(String.t()) :: struct()
  def read_config(file) do
    response =
      file
      |> Path.expand()
      |> File.read!()
      |> Jason.decode!()
      |> create_from_json()

    case response do
      {:error, message} -> exit(message)
      config when is_struct(config, __MODULE__) -> config
    end
  end

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    port = json["port"]

    bootstrap_ip =
      json["bootstrapIpAddress"]
      |> Ekser.TCP.to_ip()

    bootstrap_port = json["bootstrapPort"]

    weak_timeout = json["weakLimit"]
    strong_timeout = json["strongLimit"]

    jobs =
      json["jobs"]
      |> Ekser.Serializable.to_struct_map(Ekser.Job, fn job -> {job.name, job} end)

    new(
      port,
      Ekser.Node.new(-1, bootstrap_ip, bootstrap_port, "", ""),
      weak_timeout,
      strong_timeout,
      jobs
    )
  end

  defp new(port, bootstrap, weak_timeout, strong_timeout, jobs) do
    with {true, _} <-
           {Ekser.TCP.is_tcp_port(port), Ekser.TCP.port_prompt()},
         {true, _} <-
           {Ekser.Node.is_node(bootstrap),
            "Bootstrap must be in the form of a node (tuple with id, IP and port)."},
         {true, _} <- {is_timeout(weak_timeout), "Weak timeout must be a positive integer."},
         {true, _} <- {is_timeout(strong_timeout), "Strong timeout must be a positive integer."},
         {true, _} <-
           {Ekser.Serializable.valid_map?(jobs, Ekser.Job), "Jobs must be a valid job map."} do
      %__MODULE__{
        port: port,
        bootstrap: bootstrap,
        weak_timeout: weak_timeout,
        strong_timeout: strong_timeout,
        jobs: jobs
      }
    else
      {false, message} ->
        {:error, message}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Config do
  def encode(value, opts) do
    map = %{
      port: value.port,
      bootstrapIpAddress: Ekser.TCP.from_ip(value.bootstrap.ip),
      bootstrapPort: value.bootstrap.port,
      weakLimit: value.watchdog_timeout,
      strongLimit: value.failure_timeout,
      jobs: value.jobs
    }

    Jason.Encode.map(map, opts)
  end
end

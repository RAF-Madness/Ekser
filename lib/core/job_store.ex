defmodule Ekser.JobStore do
  require Ekser.JobMap
  require Ekser.DHT
  use Agent

  # Client API

  def start_link(opts) do
    {jobs, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(Ekser.JobMap, :init, [jobs], just_opts)
  end

  @spec job_exists?(String.t()) :: boolean()
  def job_exists?(job_name) do
    Agent.get(Ekser.JobStore, Ekser.JobMap, :has_job?, [job_name])
  end

  @spec get_job_by_name(String.t()) :: %Ekser.Job{} | nil
  def get_job_by_name(job_name) do
    Agent.get(Ekser.JobStore, Ekser.JobMap, :get_job, [job_name])
  end

  @spec get_all_jobs() :: %{String.t() => %Ekser.Job{}}
  def get_all_jobs() do
    Agent.get(Ekser.JobStore, Ekser.JobMap, :get_jobs, [])
  end

  @spec receive_job(%Ekser.Job{}) :: :ok | :unchanged
  def receive_job(job) do
    Agent.get_and_update(Ekser.JobStore, Ekser.JobMap, :add_job, [job])
  end

  @spec receive_system(%Ekser.DHT{}) :: :ok
  def receive_system(dht) do
    Agent.update(Ekser.JobStore, Ekser.JobMap, :merge_jobs, [dht.jobs])
  end
end

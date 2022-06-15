defmodule Ekser.JobMap do
  # Agent Functions

  def init(jobs) do
    jobs
  end

  def has_job?(jobs, job_name) do
    Map.has_key?(jobs, job_name)
  end

  def get_jobs(jobs) do
    jobs
  end

  def get_job(jobs, job_name) do
    jobs[job_name]
  end

  def add_job(jobs, job) do
    case has_job?(jobs, job.name) do
      true -> {:unchanged, jobs}
      false -> {:ok, Map.put(jobs, job.name, job)}
    end
  end

  def merge_jobs(jobs, system_jobs) do
    Map.merge(jobs, system_jobs)
  end
end

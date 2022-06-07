defmodule Ekser.Command.Status do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl true
  def generate() do
    Ekser.Command.new(
      "status",
      &status/3,
      [{&Ekser.Command.resolve_job/2, true}, {&Ekser.Command.resolve_id/2, true}],
      "status [X [id]]"
    )
  end

  defp status(_, _, [job, id])
       when Ekser.Job.is_job(job) and is_integer(id) do
    # send message to status supervisor
    "Collecting status for job " <> job.name <> " and id " <> Integer.to_string(id)
  end

  defp status(_, _, [job]) when Ekser.Job.is_job(job) do
    # send message to status supervisor
    "Collecting status for job " <> job.name
  end

  defp status(_, _, []) do
    # send message to status supervisor
    "Collecting status for all jobs"
  end
end

defmodule Ekser.Command.Start do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl true
  def generate() do
    Ekser.Command.new(
      "start",
      &start/3,
      [{&Ekser.Command.resolve_job/2, true}],
      "start [X]"
    )
  end

  defp start(_, _, [job]) when Ekser.Job.is_job(job) do
    # send message to worker
    "Starting job " <> job.name
  end

  defp start(input, output, []) do
    IO.puts(output, "Enter job parameters. Format: name N P WxH A1|A2|A3...")

    read_job =
      IO.gets(input, "")
      |> Ekser.Job.create_from_line()

    case read_job do
      {:ok, job} ->
        # send message to job supervisor
        {"Starting new job " <> job.name, job}

      {:error, message} ->
        message
    end
  end
end

defmodule Ekser.Command.Result do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl true
  def generate() do
    Ekser.Command.new(
      "result",
      &result/3,
      [{&Ekser.Command.resolve_job/2, false}, {&Ekser.Command.resolve_id/2, true}],
      "result X [id]"
    )
  end

  defp result(_, _, [job, id])
       when Ekser.Job.is_job(job) and is_integer(id) do
    # send message to png exporter
    "Generating fractal image for job " <> job.name <> " and node ID " <> Integer.to_string(id)
  end

  defp result(_, _, [job]) when Ekser.Job.is_job(job) do
    # send message to png exporter
    "Generating fractal image for job " <> job.name
  end
end

defmodule Ekser.Command.Stop do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl true
  def generate() do
    Ekser.Command.new(
      "stop",
      &stop/3,
      [{&Ekser.Command.resolve_job/2, false}],
      "stop X"
    )
  end

  defp stop(_, _, [job]) when Ekser.Job.is_job(job) do
    # send message to worker
    "Stopping job " <> job.name
  end
end

defmodule Ekser.Command.Pause do
  require Ekser.Command
  @behaviour Ekser.Command

  @impl true
  def generate() do
    Ekser.Command.new(
      "pause",
      &pause/3,
      [{&Ekser.Command.resolve_milliseconds/2, false}],
      "pause T"
    )
  end

  defp pause(_, _, [milliseconds]) when is_integer(milliseconds) and milliseconds > 0 do
    Process.sleep(milliseconds)
    "Successfully slept for " <> Integer.to_string(milliseconds) <> " milliseconds."
  end
end

defmodule Ekser.Command.Quit do
  require Ekser.Command
  @behaviour Ekser.Command

  @impl true
  def generate() do
    Ekser.Command.new(
      "quit",
      &quit/3,
      [],
      "quit"
    )
  end

  defp quit(_, _, []) do
    exit(:shutdown)
  end
end

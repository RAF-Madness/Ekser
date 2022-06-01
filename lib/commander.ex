# ● status [X [id]] - Prikazuje stanje svih započetih izračunavanja - broj tačaka na
# svakom fraktalu. Naznačava za svaki fraktal koliko čvorova rade na njemu, fraktalni ID, i
# koliko tačaka je svaki čvor nacrtao. Ako se navede X kao naziv izračunavanja, onda se
# dohvata status samo za njega. Ako se navede posao i fraktalni ID, onda se dohvata status
# samo od čvora sa tim ID.
# ● start [X] - Započinje izračunavanje za zadati posao X. X može da bude simboličko
# ime nekog posla navedenog u konfiguracionoj datoteci. Ako se X izostavi, pitati korisnika
# da unese parametre za posao na konzoli. Proveriti da je ime posla jedinstveno, kao i da su
# svi parametri validnih tipova. Ako je ovo K-ti posao u sistemu, neophodno je da ima makar
# K čvorova aktivno. Ako nema K čvorova aktivno, ne startovati posao.
# ● result X [id] - Prikazuje rezultate za završeno izračunavanje za posao X. Korisnik
# može, a ne mora da navede fraktalni ID za rezultat. Ako se izostavi, onda se dohvata
# rezultat za ceo posao, u suprotnom samo za taj fraktalni ID. Slika treba da se eksportuje
# kao PNG.
# ● stop X - Zaustavlja izračunavanje za posao X. Fraktal u potpunosti nestaje iz sistema, i
# čvorovi se preraspoređuju na druge poslove.
# ● quit - Uredno gašenje čvora
defmodule Commander do
  require Job

  @spec init(list(struct()), String.t()) :: any()
  def init(job_list, filename) do
    true = Enum.all?(job_list, fn element -> Job.is_job(element) end)

    filepath = Path.expand(filename)
    input = File.open!(filepath, [:raw, :read, :utf8])

    output =
      Path.dirname(filepath) |> Path.join("output.txt") |> File.open!([:raw, :write, :utf8])

    read(job_list, input, output)
  end

  @spec init(list(struct())) :: any()
  def init(job_list) do
    true = Enum.all?(job_list, fn element -> Job.is_job(element) end)
    read(job_list, :stdio, :stdio)
  end

  defp read(job_list, input, output) do
    {message, new_job_list} =
      IO.gets(input, "")
      |> clean_and_split()
      |> command(job_list, input, output)

    IO.puts(output, message)
    read(new_job_list, input, output)
  end

  defp clean_and_split(line) do
    String.trim(line)
    |> String.split()
  end

  defp command(args, job_list, input, output) do
    case args do
      ["status" | rest] -> {status(job_list, rest), job_list}
      ["start"] -> start_new(job_list, input, output)
      ["start" | rest] -> {start(job_list, rest), job_list}
      ["result" | rest] -> {result(job_list, rest), job_list}
      ["stop" | rest] -> {stop(job_list, rest), job_list}
      ["pause" | rest] -> {pause(rest), job_list}
      ["quit" | _] -> quit()
      _ -> {"Invalid command.", job_list}
    end
  end

  defp status(job_list, [job_name, id_string])
       when is_binary(job_name) and is_binary(id_string) do
    selected_job = Job.find_job(job_list, job_name)

    with true = selected_job !== nil,
         {id, _} <- Integer.parse(id_string) do
      # send message to status supervisor
      "Collecting status for job " <> selected_job <> " and id " <> Integer.to_string(id)
    else
      false -> "Failed to find job."
      :error -> "Failed to parse node id."
    end
  end

  defp status(job_list, [job_name]) when is_binary(job_name) do
    selected_job = Job.find_job(job_list, job_name)

    with true <- selected_job !== nil do
      # send message to status supervisor
      "Collecting status for job " <> selected_job.name
    else
      false -> "Failed to find job."
    end
  end

  defp status(job_list, []) do
    # send message to status supervisor
    "Collecting status for all jobs"
  end

  defp start(job_list, [job_name]) when is_binary(job_name) do
    selected_job = Job.find_job(job_list, job_name)

    with true <- selected_job !== nil do
      # send message to status supervisor
      "Starting job " <> selected_job.name
    else
      false -> "Failed to find job."
    end
  end

  defp start(_, _) do
    "Wrong arguments for command Start. "
  end

  defp start_new(job_list, input, output) do
    IO.puts(output, "Enter job parameters. Format: name N P WxH A1|A2|A3...")

    read_job =
      IO.gets(input, "")
      |> Job.create_from_line()

    case read_job do
      {:ok, job} ->
        # send message to job supervisor
        {"Starting new job " <> job.name, [job | job_list]}

      {:error, message} ->
        {message, job_list}
    end
  end

  defp result(job_list, [job_name, id_string])
       when is_binary(job_name) and is_binary(id_string) do
    selected_job = Job.find_job(job_list, job_name)

    with true = selected_job !== nil,
         {id, _} <- Integer.parse(id_string) do
      # send message to png exporter
      "Generating fractal image for job " <> selected_job <> " and id " <> Integer.to_string(id)
    else
      false -> "Failed to find job."
      :error -> "Failed to parse node id."
    end
  end

  defp result(job_list, [job_name]) when is_binary(job_name) do
    selected_job = Job.find_job(job_list, job_name)

    with true <- selected_job !== nil do
      # send message to png exporter
      "Generating fractal image for job " <> selected_job.name
    else
      false -> "Failed to find job."
    end
  end

  defp result(_, _) do
    "Wrong arguments for command Result. Requires a job name specifying which job to export an image for."
  end

  defp stop(job_list, [job_name]) when is_binary(job_name) do
    selected_job = Job.find_job(job_list, job_name)

    with true <- selected_job !== nil do
      # send message to job worker
      "Stopping job " <> selected_job.name
    else
      false -> "Failed to find job."
    end
  end

  defp stop(_, _) do
    "Wrong argmuents for command Stop. Requires a job name specifying which job to stop."
  end

  defp sleep(milliseconds) when is_integer(milliseconds) and milliseconds > 0 do
    Process.sleep(milliseconds)
    "Successfully slept for " <> Integer.to_string(milliseconds) <> " milliseconds."
  end

  defp pause([millisecond_string]) when is_binary(millisecond_string) do
    parseResult = Integer.parse(millisecond_string)

    case parseResult do
      {milliseconds, _} ->
        sleep(milliseconds)

      :error ->
        "Wrong arguments for command Pause. Requires a positive integer specifying how many milliseconds to wait."
    end
  end

  defp pause(_) do
    "Wrong arguments for command Pause. Requires a positive integer specifying how many milliseconds to wait."
  end

  defp quit() do
    exit(:normal)
  end
end

defmodule Commander do
   def interpret(line) do
        config = File.stream!(config_file)
        |> Enum.map(&String.trim/1)
   end
end
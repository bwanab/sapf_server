defmodule SAPFCli do
  @moduledoc """
  Enhanced CLI with better command parsing and tab completion setup.
  """

  @commands %{
    "help" => &SAPFCli.help/1,
    "midi_start" => &SAPFCli.midi_start/1,
    "midi_connect_input" => &SAPFCli.midi_connect_input/1,
    "play_midi_file" => &SAPFCli.play_midi_file/1,
    "quit" => "dork"
  }

  def start do
    # Set up tab completion for our commands
    setup_completion()

    IO.puts("Welcome to SAPF Server Tab completion is enabled.")
    IO.puts("Type 'help' for available commands or 'quit' to exit.")
    loop()
  end

  defp setup_completion do
    # Tab completion in Elixir/Erlang shell is more complex to set up
    # For now, we'll skip the automatic setup
    # Users still get history and line editing automatically
    SAPFServer.start_link(0)
  end

  defp loop do
    case get_command() do
      {:ok, {command, args}} ->
        case Map.get(@commands, command) do
          nil ->
            # command must be a direct sapf command
            SAPFServer.send_command("#{command} #{args}")
            loop()

          _fun when command == "quit" ->
            SAPFServer.quit()


          fun ->
            fun.(args)
            loop()
        end

      {:error, :interrupted} ->
        IO.puts("\nGoodbye!")
        :ok

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        loop()
    end
  end

  defp get_command do
    case IO.gets("SAPF> ") do
      :eof ->
        {:error, :eof}

      {:error, reason} ->
        {:error, reason}

      data when is_binary(data) ->
        parse_command(String.trim(data))
    end
  rescue
    _exception ->
      {:error, :interrupted}
  end

  defp parse_command(""), do: {:ok, {"", []}}

  defp parse_command(input) do
    case String.split(input, " ", parts: 2) do
      [command] -> {:ok, {command, []}}
      [command, args] -> {:ok, {command, [args]}}
    end
  end

  # Command implementations
  def help(_args) do
    IO.puts("""
    Available commands:
      help                - Show this help message
      midi_start          - enhanced midi start
      midi_connect_input  - connect the sapf input
      play_midi_file      - play a midi file
      any sapf command    - does what sapf does

    Features:
      - Use arrow keys for command history
      - Use Ctrl+R for reverse search
      - Use Tab for command completion
      - Use Ctrl+C to exit
    """)
  end

  def midi_start(_args) do
    SAPFServer.midi_start()
  end

  def midi_connect_input(_args) do
    SAPFServer.connect_input()
  end

  def play_midi_file(filename) do
    SAPFServer.play_midi_file(filename)
  end

  def quit(_args) do
    exit(:normal)
  end

end

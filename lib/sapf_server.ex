defmodule SAPFServer do
  use GenServer

  @moduledoc """
  Provides a currently limited wrapper around [Sound as Pure Form](https://github.com/lfnoise/sapf)

  Example use:


      ; play a midi file using a very simple synth defined by a
      ; local file sapf_snippets.sapf. The key to creating a
      ; synth that works is
      ; 1 mlastkey to get the note on events,
      ; 2 an oscillator like sinosc
      ; 3 play at the end

      SAPFServer.start_link(0)
      SAPFServer.midi_start()
      SAPFServer.connect_input()
      SAPFServer.play("Yourmidifile.mid", "sapf_snippets.sapf")

  You can send any command to sapf:

      SAPFServer.send_command("5 4 *")
      -> 20

      SAPFServer.send_command("60 nnhz 0 sinosc 0.2 * play") ; plays a middle C sine wave note until stopped

      SAPFServer.stop()                           ; stops the sine wave note :)

      SAPFServer.quit()                           ; shuts down sapf and the sapf server

  """

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def send_command(command, param \\ "") do
    if is_binary(param) and String.length(param) == 0 do
      GenServer.call(__MODULE__, {:send_command, command, param, nil})
    else
      task = Task.async(fn ->
        reply_pid = self()
        # IO.inspect(reply_pid, label: "reply_pid when called")
        GenServer.call(__MODULE__, {:send_command, command, param, reply_pid})
        # Wait for completion message
        receive do
          :command_completed ->
            :ok
        after
          5000 -> {:error, :timeout}
        end
      end)
      Task.await(task)
    end
  end

  def midi_start() do
    sapf_port = Midiex.create_virtual_output("sapf")
    send_command("midiStart", sapf_port)
  end

  def get_devices() do
    GenServer.call(__MODULE__, :get_device_list)
  end

  def get_device(device) do
    Map.get(get_devices(), device)
  end

  def get_sapf_port() do
    GenServer.call(__MODULE__, :get_sapf_port)
  end

  def connect_input(device \\ "sapf") do
    m = get_device(device)
    command = EEx.eval_string("<%= uid %> <%= dev %> midiConnectInput", Keyword.new(m))
    send_command(command)
  end

  def build_synth(file_name, device \\ "sapf") do
    if File.exists?(file_name) do
      m = get_device(device)
      stuff = EEx.eval_file(file_name, Keyword.new(m))
      Enum.each(String.split(stuff, "\n"), fn s ->
        send_command(s)
      end)
      :ok
    else
      {:error, "File #{file_name} doesn't exist"}
    end
  end

  def quit() do
    send_command("quit")
  end

  def stop() do
    send_command("stop")
  end

  def play(d, opts \\ [])
  def play(name, opts)  when is_binary(name) do
    seq = Midifile.read(name)
    play(seq, opts)
  end

  def play(%Midifile.Sequence{} = seq, opts) do
    synth_file = Keyword.get(opts, :synth_file, "sapf_snippets.sapf")
    case build_synth(synth_file) do
      :ok ->
        MidiPlayer.play(seq, synth: get_sapf_port())
      {:error, msg} -> IO.puts(msg)
    end
  end

  def play(stm, opts) do
    bpm = Keyword.get(opts, :bpm, 100)
    tpqn = Keyword.get(opts, :tpqn, 960)
    seq = MusicBuild.Util.build_sequence(stm, "dork", bpm, tpqn)
    play(seq, opts)
  end

  def init(_arg) do
    port = Port.open({:spawn, "script -q /dev/null sapf"}, [
      :binary,
      :exit_status,
      {:line, 1024}
    ])
    {:ok, %{port: port,
            responses: [],
            current_command: "",
            device_list: %{},
            sapf_port: nil,
            param: "",
            timer_ref: nil,
            command_pid: nil
            }}
  end

  def handle_call({:send_command, command, param, reply_pid}, _from, %{port: port} = state) do
    Port.command(port, command <> "\n")
    # IO.inspect(command)
    {:reply, :ok, %{state | current_command: command, responses: [], param: param, command_pid: reply_pid}}
  end

  def handle_call(:get_device_list, _from, %{device_list: device_list} = state) do
    {:reply, device_list, state}
  end

  def handle_call(:get_sapf_port, _from, %{sapf_port: sapf_port} = state) do
    {:reply, sapf_port, state}
  end

  def handle_info({port, {:data, {:eol, line}}}, %{port: port, responses: resp} = state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Start new timer
    timer_ref = Process.send_after(self(), :response_timeout, 100)  # Short timeout
    {:noreply, %{state | responses: [line | resp], timer_ref: timer_ref}}
  end

  def handle_info(:response_timeout, %{responses: resp, current_command: cmd, param: param, command_pid: reply_pid} = state) do
    Enum.each(resp, fn s -> if not String.contains?(s, "sapf>"), do: IO.puts(s) end)
    if cmd == "midiStart" do
      # IO.inspect(reply_pid, label: "reply_pid")
      if reply_pid, do: send(reply_pid, :command_completed)
      {:noreply, %{state | sapf_port: param,
                           device_list: parse_midi_start(Enum.reverse(resp)),
                           timer_ref: nil,
                           current_command: "",
                           param: "",
                           responses: [],
                           command_pid: nil
                          }}
    else
      {:noreply, %{state | timer_ref: nil}}
    end
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    IO.puts("sapf exited with status: #{status}")
    {:stop, :normal, state}
  end

  def parse_midi_start(lines) do
    Enum.drop_while(lines, fn s -> not String.starts_with?(s, "MIDI") end)
    |> Enum.map(fn s -> String.split(s, ",") end)
    |> Enum.map(fn [s1, s2] ->
      [_, _, device_num_str, device_name | _r] = split_with_quotes(s1)
      [_, _, uid_str] = split_with_quotes(s2)
      {String.replace(device_name, "'", ""), %{uid: String.to_integer(uid_str), dev: String.to_integer(device_num_str)}}
    end)
    |> Map.new
  end

  def split_with_quotes(string) do
    # Regex to match either quoted strings or unquoted words
    ~r/'[^']*'|[^\s']+/
    |> Regex.scan(string)
    |> List.flatten()
  end

end

Mix.install([
  {:music_build, github: "bwanab/music_build"},
  {:sapf_server, path: "."}
])
synth_file = case System.argv() do
  [] -> "synths/basic_synth.sapf"
  [file] -> file
end

chords = MusicBuild.Examples.ArpeggioProgressions.build_chords([:I, :V, :vi, :iii, :IV, :I, :IV, :V], :C, 3, 1, 0)
patterns = [
  [4,1,2,3],
  [1,2,4,3],
  [2,3,4,2],
  [1,4,3,1],
  [1,2,3,4],
  [1,4,3,1],
  [1,2,3,2],
  [2,3,4,1]
]
arpeggios = (Enum.map(Enum.zip(chords, patterns), fn {c, p} -> Arpeggio.new(c, p, 0.5, 0) end)
            |> List.duplicate(3)
            |> List.flatten)
stm = %{0 => STrack.new(arpeggios, name: "arpeggios", tpqn: 960, type: :instrument, program_number: 73, bpm: 100)}
# MidiPlayer.play(stm)
SAPFServer.start_link(0)
SAPFServer.midi_start()
SAPFServer.connect_input()
SAPFServer.send_control_message(20, 10)
SAPFServer.send_control_message(21, 10)
SAPFServer.send_control_message(22, 10)
SAPFServer.send_control_message(23, 10)
SAPFServer.play(stm, synth_file: synth_file)
SAPFServer.quit()

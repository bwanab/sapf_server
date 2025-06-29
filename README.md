# SAPFServer

SAPFServer is a wrapper for the incredible [Sound As Pure Form](https://github.com/lfnoise/sapf) abreviated
as sapf, written by James McCartney, the author of the also incredible SuperCollider project.

The purpose and motivation behind this wrapper is to be able to create musical forms in Elixir and
have them executed using sapf. 

## Example usage

  iex> Import SAPFServer

  iex> start_link(0)                 # start the server
  
  iex> midi_start()                  # initialize sapf for midi, this also sets up a virtual midi port for Midiex
  
  iex> connect_input()               # connect the virtual midi port to sapf
  
  iex> play_midi_file("Yourmidifile.mid") # this plays by default using a simple synth set up in sapf_snippets.sapf

One can also send any command to sapf that one can directly to sapf:

  iex> send_command("3 4 *") -> 12
  
  iex> send_command("60 nnhz 0 sinosc 0.2 * play") -> plays a middle C until
  
  iex> stop
  
In addition, there is a simple command line utility that allows one to interact with sapf as one would directly:

  iex> SAPFCli.start()
  
  SAPF> 3 4 * -> 12
  
  SAPF> 60 nnhz 0 sinosc 0.2 * play -> plays a middle C
  
  SAPF> stop

The command line also knows the added functionality of the SAPFServer:

  SAPF> midi_start
  
  SAPF> connect_input
  
  SAPF> play_midi_file Yourmidifile.mid

## Installation

Currently only available via source from github:

```elixir
def deps do
  [
    {:sapf_server, github: "bwanab/sapf_server"}
  ]
end
```

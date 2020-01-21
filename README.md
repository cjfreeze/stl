# STL
`STL` is a library for reading and analyzing ASCII STL 3D model files.

[![Hex](https://img.shields.io/hexpm/v/stl.svg?style=flat)](https://hexdocs.pm/stl/0.1.0/STL.html)


**NOTE**: Library does not support binary STL files.

**NOTE**: Library does not support facet normal vector calculation. Normal vectors are currently always data read from file.

For more information on the STL files and the STL spec, see [the wikipedia page](https://en.wikipedia.org/wiki/STL_(file_format)).
## Installation
If using in an existing Elixir project:
```elixir
def deps do
  [{:stl, github: "cjfreeze/stl"}]
end
# or
def deps do
  [{:stl, "~> 0.1.0"}]
end
```
If experimenting with standalone:
```
git clone git@github.com:cjfreeze/stl.git
cd stl
mix deps.get
mix iex -S mix
```
## Usage
STL generates `%STL{}` structs from ASCII STL files or binaries.

For more information on any of the functions mentioned below, be sure to check out the [docs!](https://hexdocs.pm/stl/0.1.0/STL.html)

To use, call either `STL.parse!(stl_binary)` or `STL.parse_file!(stl_filename)` to build a struct from your data:
```elixir
iex> stl = STL.parse!(stl_binary)
%STL{name: "MYSTL", ...}
# or
iex> stl = STL.parse_file!("my.stl")
%STL{name: "MYSTL", ...}
```
This struct can be used with the analysis functions `triangle_count/1`, `bounding_box/1`, and `surface_area/1` to get basic information about your file:
```elixir
iex> STL.triangle_count(stl)
1000

iex> STL.surface_area(stl)
1000.0

iex> STL.bounding_box(stl)
[
  {1.0, 1.0, 1.0},
  {1.0, 1.0, -1.0},
  {1.0, -1.0, 1.0},
  {1.0, -1.0, -1.0},
  {-1.0, 1.0, 1.0},
  {-1.0, 1.0, -1.0},
  {-1.0, -1.0, 1.0},
  {-1.0, -1.0, -1.0}
]
```
You can also work directly with the `STL` struct, which has data such as `:name`, and a list of `:facets` defined in the STL file:
```elixir
iex> name = stl.name
"MYSTL"

iex> first_facet = hd(stl.facets)
%STL.Facet{...}
```

You can write your own parser by implementing the `STL.Parser` behaviour, and setting the following config value:
```elixir
config :stl, :parser, MyApp.MySTLParser # defaults to STL.Parser.Stream
```

As an experiment, I wrote another parser using [NimbleParsec](https://github.com/plataformatec/nimble_parsec), called `STL.Parser.Nimble`. It has some quirks, but feel free to experiment with it. You can set the parser at runtime to easily experiment by providing it as an optional second argument to either `parse!` function:
```elixir
iex> STL.parse_file!("my.stl", STL.Parser.Nimble)
# or
iex> STL.parse!(stl_binary, STL.Parser.Nimble)
```
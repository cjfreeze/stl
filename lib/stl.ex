defmodule STL do
  @moduledoc """
  Functions for working with STL files and structs. Triangle count and bounding box
  finding is done during parsing and is a constant-time operation.
  Surface area calculation, if not able to be calculated during parsing,
  is done every time the function is called and thus is potentially an expensive operation.
  """
  defstruct name: nil, facets: [], triangle_count: nil, bounding_box: nil, surface_area: nil

  @typedoc """
  Dimensions are always in the order {x, y, z}
  """
  @type point :: {float, float, float}
  @typedoc """
  Will always have exactly 8 points in the list, equivelant to the number of vertexes a box has.
  """
  @type bounding_box :: [point, ...]
  @type t :: %STL{
          name: String.t(),
          facets: [STL.Facet.t(), ...],
          triangle_count: integer(),
          bounding_box: bounding_box(),
          surface_area: float()
        }
  @default_parser STL.Parser.Stream
  @doc """
  Parse a STL struct from a binary
  ```
  iex> STL.parse!(stl_binary)
  %STL{...}
  ```
  Specify the parser with the optional second argument
  ```
  iex> STL.parse!(stl_binary, MyApp.Parser)
  %STL{...}
  ```
  """
  def parse!(binary) do
    parse!(binary, get_parser())
  end

  def parse!(binary, parser) do
    parser.parse!(binary)
  end

  @doc """
  Parse a STL struct from a file.
  ```
  iex> STL.parse_file!("my.stl")
  %STL{...}
  ```
  Specify the parser with the optional second argument
  ```
  iex> STL.parse_file!("my.stl", MyApp.Parser)
  %STL{...}
  ```
  """
  def parse_file!(file) do
    parse_file!(file, get_parser())
  end

  def parse_file!(file, parser) do
    parser.parse_file!(file)
  end

  defp get_parser do
    Application.get_env(:stl, :parser, @default_parser)
  end

  @doc """
  Get the triangle count of the STL file
  ```
  iex> STL.triangle_count(my_stl)
  100
  ```
  """
  def triangle_count(%STL{triangle_count: count}), do: count

  @doc """
  Get the 8 points of the STL file's bounding box.
  Points are returned as 3 item tuples with float values.
  Dimensions are always in the order {x, y, z}
  ```
  iex> STL.bounding_box(my_stl)
  [
    {26.5269, 90.2, 13.5885},
    {26.5269, 90.2, -13.6694},
    {26.5269, 4.426, 13.5885},
    {26.5269, 4.426, -13.6694},
    {-26.5748, 90.2, 13.5885},
    {-26.5748, 90.2, -13.6694},
    {-26.5748, 4.426, 13.5885},
    {-26.5748, 4.426, -13.6694}
  ]
  ```
  """
  def bounding_box(%STL{bounding_box: box}), do: box

  @doc """
  Get a pre-summed surface area off the STL struct, or if if not already calculated,
  sum the area of every facet in the STL file to get the total STL surface_area.
  ```
  iex> STL.surface_area(my_stl)
  1000
  ```
  """
  def surface_area(%STL{surface_area: surface_area}) when not is_nil(surface_area),
    do: surface_area

  def surface_area(%STL{facets: facets}) do
    Enum.reduce(facets, 0, fn
      %{surface_area: surface_area}, sum when not is_nil(surface_area) -> sum + surface_area
      facet, sum -> STL.Geo.facet_area(facet) + sum
    end)
  end
end

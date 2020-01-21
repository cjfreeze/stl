defmodule STL.Parser.Nimble do
  @moduledoc """
  A STL Parser written using https://hexdocs.pm/nimble_parsec/NimbleParsec.html
  Implements STL.Parser behaviour. Also includes triangle count and STL bounding
  box analysis steps during parser output formatting.

  Developer's note: "I think my post processing steps could potentially be done during parsing by leveraging
  all of NimbleParsec's features, but I don't understand NimbleParsec well enough yet to try."
  """
  import NimbleParsec
  alias STL
  alias STL.{Facet, Geo}
  @behaviour STL.Parser
  ranges = [?a..?z, ?A..?Z]
  float_ranges = [?0..?9, ?., ?e, ?E, ?-, ?+]
  defparsecp(:ws, ignore(repeat(ascii_char([?\t, 32, ?\n, ?\r]))), inline: true)

  point =
    empty()
    |> concat(parsec(:ws))
    |> ascii_string(float_ranges, min: 1)
    |> concat(parsec(:ws))
    |> ascii_string(float_ranges, min: 1)
    |> concat(parsec(:ws))
    |> ascii_string(float_ranges, min: 1)

  defparsecp(:point, point, inline: true)

  facet =
    ignore(string("facet"))
    |> concat(parsec(:ws))
    |> ignore(string("normal"))
    |> concat(parsec(:ws))
    |> tag(parsec(:point), :normal)
    |> concat(parsec(:ws))
    |> ignore(string("outer"))
    |> concat(parsec(:ws))
    |> ignore(string("loop"))
    |> concat(parsec(:ws))
    |> ignore(string("vertex"))
    |> tag(
      empty()
      |> wrap(parsec(:point))
      |> concat(parsec(:ws))
      |> ignore(string("vertex"))
      |> wrap(parsec(:point))
      |> concat(parsec(:ws))
      |> ignore(string("vertex"))
      |> wrap(parsec(:point)),
      :vertexes
    )
    |> concat(parsec(:ws))
    |> ignore(string("endloop"))
    |> concat(parsec(:ws))
    |> ignore(string("endfacet"))
    |> concat(parsec(:ws))

  defparsecp(:facet, facet, inline: true)

  stl =
    parsec(:ws)
    |> ignore(string("solid "))
    |> concat(parsec(:ws))
    |> tag(ascii_string(ranges, min: 1), :name)
    |> concat(parsec(:ws))
    |> times(parsec(:facet), min: 1)
    |> concat(parsec(:ws))
    |> ignore(string("endsolid"))
    |> concat(parsec(:ws))
    |> ignore(optional(ascii_string(ranges, min: 1)))
    |> concat(parsec(:ws))

  # `defparsecp(:nimble_parse_stl, ...)` compiles to the equivelant of:
  # defp nimble_parse_stl(...) do
  #   ...
  # end
  defparsecp(:nimble_parse_stl, stl, inline: true)

  @doc """
  Reads a file using `File.read!()` then calls `Parser.Nimble.parse!()`
  """
  def parse_file!(file) do
    file
    |> File.read!()
    |> parse!()
  end

  @doc """
  Uses NimbleParsec to parse a complete STL binary and formats result into a %STL{}
  struct with triangle count and bounding box analysis. Does not calculate surface area.
  """
  def parse!(binary) do
    # nimble_parse_stl/1 is a private function generated from `defparsecp(:nimble_parse_stl, stl, inline: true)`
    # For more information, go to https://hexdocs.pm/nimble_parsec/NimbleParsec.html
    binary
    |> nimble_parse_stl()
    |> case do
      {:ok, parsed, _, _, _, _} ->
        build_struct(parsed)

      {:error, reason, _, _, _, _} ->
        raise ArgumentError, reason
    end
  end

  defp build_struct([{:name, [name]} | parsed]) do
    build_facets(%STL{name: name}, parsed)
  end

  defp build_struct(parsed) do
    build_facets(%STL{}, parsed)
  end

  defp build_facets(stl, parsed, tris \\ 0, extremes \\ nil)

  defp build_facets(%STL{} = stl, [], tris, extremes),
    do: %{stl | triangle_count: tris, bounding_box: box_from_extremes(extremes)}

  defp build_facets(%STL{} = stl, [{:normal, point} | parsed], tris, extremes) do
    add_vertexes_to_facet(stl, %Facet{normal: parse_point(point)}, parsed, tris + 1, extremes)
  end

  defp add_vertexes_to_facet(
         %STL{facets: facets} = stl,
         %Facet{} = facet,
         [
           {:vertexes, vertexes} | parsed
         ],
         tris,
         extremes
       ) do
    parsed_vertexes = parse_vertex_points(vertexes)
    new_facet = %Facet{facet | vertexes: parsed_vertexes}
    surface_area = Geo.facet_area(new_facet)

    build_facets(
      %STL{stl | facets: [%Facet{new_facet | surface_area: surface_area} | facets]},
      parsed,
      tris,
      update_extremes(extremes, parsed_vertexes)
    )
  end

  defp parse_vertex_points([vertex_1, vertex_2, vertex_3]) do
    {parse_point(vertex_1), parse_point(vertex_2), parse_point(vertex_3)}
  end

  defp parse_point([x, y, z]) do
    {parse_float(x), parse_float(y), parse_float(z)}
  end

  defp parse_float(float) do
    case Float.parse(float) do
      {float, _} ->
        float

      _ ->
        raise ArgumentError, "Malformed float from STL #{inspect(float)}"
    end
  end

  defp update_extremes(extremes, {a, b, c}) do
    extremes
    |> do_update_extremes(a)
    |> do_update_extremes(b)
    |> do_update_extremes(c)
  end

  defp do_update_extremes(nil, {x, y, z}), do: {x, x, y, y, z, z}

  # x1, y1, and z1 are upper extremes
  # x2, y2, and z2 are lower extremes
  defp do_update_extremes({x1, x2, y1, y2, z1, z2}, {x, y, z}) do
    x1 = if(x > x1, do: x, else: x1)
    x2 = if(x < x2, do: x, else: x2)
    y1 = if(y > y1, do: y, else: y1)
    y2 = if(y < y2, do: y, else: y2)
    z1 = if(z > z1, do: z, else: z1)
    z2 = if(z < z2, do: z, else: z2)
    {x1, x2, y1, y2, z1, z2}
  end

  defp box_from_extremes({x1, x2, y1, y2, z1, z2}) do
    for x <- [x1, x2],
        y <- [y1, y2],
        z <- [z1, z2],
        do: {x, y, z}
  end
end

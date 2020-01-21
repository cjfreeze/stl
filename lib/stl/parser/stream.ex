defmodule STL.Parser.Stream do
  @moduledoc """
  A single-pass streamed STL Parser.
  Implements STL.Parser behaviour. Also includes triangle count, STL bounding
  box analysis, and total model surface area analysis steps during parsing.
  """
  alias STL.{Geo, Facet}
  @behaviour STL.Parser

  defp init_state do
    %{
      step: :init,
      stl: %STL{},
      facet: nil,
      point: nil,
      extremes: nil,
      surface_area: 0,
      tris: 0
    }
  end

  def parse!(binary) do
    handle_line(binary, init_state())
  end

  def parse_file!(file) do
    file
    |> File.stream!()
    |> Enum.reduce(init_state(), &handle_line/2)
  end

  # Since this parser already expects one line at a time, with unlimited whitespace/newlines between keywords and fields,
  # it would not be hard to amend the parser to allow for parsing partial STL files, allowing a stl file with
  # potentially millions of triangles to be leisurely processed as needed, line by line, with a parser manager
  # holding the returned incomplete state of the parser while it waits for system resources to become available
  # or for more lines to be received.
  defp handle_line("", state), do: state

  defp handle_line(<<char::binary-size(1), rest::binary>>, state)
       when char in [" ", "\n", "\t", "\r"] do
    handle_line(rest, state)
  end

  defp handle_line("solid " <> rest, %{step: :init} = state) do
    handle_line(rest, %{state | step: :name_or_facet})
  end

  defp handle_line("facet" <> rest, %{step: step} = state)
       when step in ~w(name_or_facet facet facet_or_end_solid)a do
    handle_line(rest, %{state | step: :normal, facet: %Facet{}})
  end

  defp handle_line("normal" <> rest, %{step: :normal} = state) do
    handle_line(rest, %{state | step: :normal, point: {nil, nil, nil}})
  end

  defp handle_line("outer" <> rest, %{step: :outer} = state) do
    handle_line(rest, %{state | step: :loop})
  end

  defp handle_line("loop" <> rest, %{step: :loop} = state) do
    handle_line(rest, %{state | step: :vertex_1, point: nil})
  end

  defp handle_line("vertex" <> rest, %{step: step, point: nil} = state)
       when step in ~w(vertex_1 vertex_2 vertex_3)a do
    handle_line(rest, %{state | step: step, point: {nil, nil, nil}})
  end

  defp handle_line("endloop" <> rest, %{step: :end_loop} = state) do
    handle_line(rest, %{state | step: :end_facet})
  end

  defp handle_line("endfacet" <> rest, %{step: :end_facet} = state) do
    handle_line(rest, %{state | step: :facet_or_end_solid})
  end

  defp handle_line("endsolid" <> _rest, %{
         step: :facet_or_end_solid,
         stl: stl,
         tris: tris,
         surface_area: surface_area,
         extremes: extremes
       }) do
    %STL{
      stl
      | triangle_count: tris,
        surface_area: surface_area,
        bounding_box: box_from_extremes(extremes)
    }
  end

  defp handle_line(
         <<char::binary-size(1), rest::binary>>,
         %{step: :name_or_facet, stl: stl} = state
       ) do
    {name, rest} = parse_field(rest, [char])
    handle_line(rest, %{state | step: :facet, stl: %STL{stl | name: name}})
  end

  for step <- ~w(normal vertex_1 vertex_2 vertex_3)a do
    defp handle_line(
           <<char::binary-size(1), rest::binary>>,
           %{step: unquote(step), point: {nil, nil, nil}} = state
         ) do
      {x, rest} = parse_field(rest, [char])
      handle_line(rest, %{state | point: {parse_float!(x), nil, nil}})
    end

    defp handle_line(
           <<char::binary-size(1), rest::binary>>,
           %{step: unquote(step), point: {x, nil, nil}} = state
         ) do
      {y, rest} = parse_field(rest, [char])
      handle_line(rest, %{state | point: {x, parse_float!(y), nil}})
    end

    defp handle_line(
           <<char::binary-size(1), rest::binary>>,
           %{step: unquote(step), point: {x, y, nil}} = state
         ) do
      {z, rest} = parse_field(rest, [char])
      point = {x, y, parse_float!(z)}
      handle_point(unquote(step), rest, state, point)
    end
  end

  defp handle_point(:normal, rest, %{facet: facet} = state, normal) do
    handle_line(rest, %{state | step: :outer, facet: %Facet{facet | normal: normal}, point: nil})
  end

  defp handle_point(:vertex_1, rest, %{facet: facet} = state, vertex_1) do
    handle_line(rest, %{
      state
      | step: :vertex_2,
        facet: %Facet{facet | vertexes: {vertex_1, nil, nil}},
        point: nil
    })
  end

  defp handle_point(
         :vertex_2,
         rest,
         %{facet: %Facet{vertexes: {vertex_1, _, _}} = facet} = state,
         vertex_2
       ) do
    handle_line(rest, %{
      state
      | step: :vertex_3,
        facet: %Facet{facet | vertexes: {vertex_1, vertex_2, nil}},
        point: nil
    })
  end

  defp handle_point(
         :vertex_3,
         rest,
         %{
           facet: %Facet{vertexes: {vertex_1, vertex_2, _}} = facet,
           stl: stl,
           tris: tris,
           extremes: extremes,
           surface_area: surface_area
         } = state,
         vertex_3
       ) do
    vertexes = {vertex_1, vertex_2, vertex_3}
    facet = %Facet{facet | vertexes: vertexes}
    facet_surface_area = Geo.facet_area(facet)
    new_extremes = update_extremes(extremes, vertexes)
    facet_with_surface_area = %Facet{facet | vertexes: vertexes, surface_area: facet_surface_area}

    handle_line(rest, %{
      state
      | step: :end_loop,
        stl: %STL{stl | facets: [facet_with_surface_area | stl.facets]},
        facet: nil,
        point: nil,
        tris: tris + 1,
        extremes: new_extremes,
        surface_area: surface_area + facet_surface_area
    })
  end

  defp parse_field("", _name_iodata) do
    raise ArgumentError, "Unexpectedly reached end of line while parsing field"
  end

  defp parse_field(<<char::binary-size(1), rest::binary>>, iodata)
       when char in [" ", "\n", "\t", "\r"] do
    {IO.iodata_to_binary(iodata), rest}
  end

  defp parse_field(<<char::binary-size(1), rest::binary>>, iodata) do
    parse_field(rest, [iodata | char])
  end

  defp parse_float!(float) do
    case Float.parse(float) do
      {float, _} ->
        float

      _ ->
        raise ArgumentError, "Malformed float from STL #{inspect(float)}"
    end
  end

  # Duplicated from Parser.Nimble but not significant enough that I care about extracting into a separate module
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

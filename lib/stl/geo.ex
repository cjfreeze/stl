defmodule STL.Geo do
  @moduledoc """
  Module for functions which handle geospatial calculations.
  """
  alias STL.Facet

  @doc """
  A rough implementation of Heron's formula for triangle area.
  Accepts a %STL.Facet{} and calculates its area using Heron's formula.
  """
  def facet_area(%Facet{vertexes: {vert_a, vert_b, vert_c}}) do
    a = distance_between(vert_a, vert_b)
    b = distance_between(vert_b, vert_c)
    c = distance_between(vert_c, vert_a)
    s = (a + b + c) / 2
    :math.sqrt(abs(s * (s - a) * (s - b) * (s - c)))
  end

  @doc """
  Calculates the distance beteween two 3d points.
  """
  def distance_between({x1, y1, z1}, {x2, y2, z2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2) + :math.pow(z2 - z1, 2))
  end
end

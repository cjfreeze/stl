defmodule STL.Facet do
  @moduledoc false
  defstruct ~w(normal vertexes surface_area)a

  @typedoc """
  Dimensions are always in the order {x, y, z}
  """
  @type point :: {float, float, float}
  @type t :: %__MODULE__{
          normal: point(),
          vertexes: {point(), point(), point()},
          surface_area: float()
        }
end

defmodule STL.Parser do
  @moduledoc """
  A Parser behaviour for STL. By implementing this behaviour, you can write your own
  STL parser and use it by configuring :parser under the application :stl
  ```
  config :stl, :parser, MyApp.MySTLParser
  ```
  """
  @callback parse!(binary) :: STL.t()
  @callback parse_file!(binary) :: STL.t()
end

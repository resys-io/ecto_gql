defmodule EctoGQL.Schema do
  defmacro __using__(_) do
    quote do
      use Absinthe.Schema
      import_types(Absinthe.Type.Custom)
      import_types(EctoGQL.Types)
    end
  end
end

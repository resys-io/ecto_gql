defmodule EctoGQL.Mutation do
  import EctoGQL.Helpers

  defmacro __using__(_) do
    quote do
      import EctoGQL.Mutation
    end
  end

  defmacro mutations(name, do: block) do
    quote do
      Absinthe.Schema.Notation.object unquote(name) do
        unquote(block)
      end
    end
  end

  defmacro mutation(name, do: block) do
    object_name = get_module_attr(__CALLER__, :object_singular)

    quote do
      Absinthe.Schema.Notation.field unquote(name), type: unquote(object_name) do
        unquote(block)
      end
    end
  end
end

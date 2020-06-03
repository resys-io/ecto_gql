defmodule EctoGQL do
  require Ecto.Query
  import EctoGQL.Helpers

  defmacro __using__(opts) do
    env = __CALLER__
    get_opt_value(env, opts, :schema) |> set_module_attr(:schema, env)
    get_opt_value(env, opts, :singular) |> set_module_attr(:object_singular, env)
    get_opt_value(env, opts, :plural) |> set_module_attr(:object_plural, env)

    quote do
      # (TODO) in Absinthe 1.5, you could do:
      # use Absinthe.Schema.Notation, only: []
      use Absinthe.Schema.Notation, except: [field: 2, field: 3, object: 3, arg: 2, arg: 3]
      use EctoGQL.Query
      use EctoGQL.Mutation
      import EctoGQL
      import Ecto.Query, warn: false
      @before_compile EctoGQL.Query
      # TODO: should seek configuration directly for :ecto_gql application
      @repo Application.get_env(:ecto_gql, :ecto_repo)

      def __repo__() do
        @repo
      end
    end
  end

  defmacro arg(name) do
    type = get_gql_type(get_schema(__CALLER__), name)
    do_arg(name, type, [])
  end

  defmacro arg(name, opts) when is_list(opts) do
    type = get_gql_type(get_schema(__CALLER__), name)
    do_arg(name, type, opts)
  end

  defmacro arg(name, type) do
    do_arg(name, type, [])
  end

  defmacro arg(name, type, opts) do
    do_arg(name, type, opts)
  end

  defp do_arg(name, type, opts) do
    nullable = Keyword.get(opts, :null, true)

    if nullable do
      quote do
        Absinthe.Schema.Notation.arg(unquote(name), unquote(type))
      end
    else
      quote do
        Absinthe.Schema.Notation.arg(unquote(name), non_null(unquote(type)))
      end
    end
  end

  defp get_opt_value(env, opts, name) do
    opts
    |> Keyword.fetch!(name)
    |> Macro.expand(env)
  end
end

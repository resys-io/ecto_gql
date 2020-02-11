defmodule EctoGQL.Query do
  import EctoGQL.Helpers

  defmacro __using__(_) do
    env = __CALLER__
    Module.register_attribute(env.module, :query_mutations, accumulate: true)
    Module.register_attribute(env.module, :result_mutations, accumulate: true)
    Module.register_attribute(env.module, :argument_handlers, accumulate: true)

    quote do
      import EctoGQL.Query
    end
  end

  defmacro query(queries_name, do: block) do
    object_singular = get_module_attr(__CALLER__, :object_singular)
    object_plural = get_module_attr(__CALLER__, :object_plural)

    quote do
      Absinthe.Schema.Notation.object unquote(queries_name) do
        Absinthe.Schema.Notation.field unquote(object_plural),
                                       list_of(unquote(object_singular)) do
          Absinthe.Schema.Notation.resolve(&__MODULE__.resolve_all/3)
          unquote(block)
        end

        Absinthe.Schema.Notation.field unquote(object_singular), unquote(object_singular) do
          Absinthe.Schema.Notation.resolve(&__MODULE__.resolve_single/3)
          unquote(block)
        end

        unquote(connection_field(object_plural, block))
      end
    end
  end

  defmacro object(do: block) do
    object_singular = get_module_attr(__CALLER__, :object_singular)
    object_plural = get_module_attr(__CALLER__, :object_plural)

    quote do
      Absinthe.Schema.Notation.object unquote(object_singular) do
        unquote(block)
      end

      unquote(connection_object_body(object_singular, object_plural))
    end
  end

  defp ident(base, category) do
    :"#{base}_#{category}"
  end

  defp connection_field(name, block) do
    connection_name = ident(name, :connection)

    quote do
      Absinthe.Schema.Notation.field unquote(connection_name), unquote(connection_name) do
        Absinthe.Schema.Notation.resolve(&__MODULE__.resolve_connection/3)
        unquote(paginate_args(:both))
        unquote(order_by_arg())
        unquote(block)
      end
    end
  end

  defp connection_object_body(singular_name, plural_name) do
    # TODO: check https://github.com/absinthe-graphql/absinthe_relay/blob/v1.4.6/lib/absinthe/relay/connection/notation.ex#L219
    connection_name = ident(plural_name, :connection)
    edge_name = ident(singular_name, :edge)

    quote do
      Absinthe.Schema.Notation.object unquote(edge_name) do
        Absinthe.Schema.Notation.field(:cursor, :string)
        Absinthe.Schema.Notation.field(:node, unquote(singular_name))
      end

      Absinthe.Schema.Notation.object unquote(connection_name) do
        Absinthe.Schema.Notation.field(:page_info, :page_info)
        Absinthe.Schema.Notation.field(:edges, list_of(unquote(edge_name)))
      end
    end
  end

  # Forward pagination arguments.
  #
  # Arguments appropriate to include on a field whose type is a connection
  # with forward pagination.
  defp paginate_args(:forward) do
    quote do
      arg(:after, :string)
      arg(:first, :integer)
    end
  end

  # Backward pagination arguments.

  # Arguments appropriate to include on a field whose type is a connection
  # with backward pagination.
  defp paginate_args(:backward) do
    quote do
      arg(:before, :string)
      arg(:last, :integer)
    end
  end

  # Pagination arguments (both forward and backward).

  # Arguments appropriate to include on a field whose type is a connection
  # with both forward and backward pagination.
  defp paginate_args(:both) do
    [
      paginate_args(:forward),
      paginate_args(:backward)
    ]
  end

  defmacro field(name) do
    schema = get_schema(__CALLER__)
    type = get_gql_type(schema, name)
    do_field(name, type)
  end

  defmacro field(name, type) do
    do_field(name, type)
  end

  defp do_field(name, type) do
    quote do
      Absinthe.Schema.Notation.field(unquote(name), unquote(type))
    end
  end

  defp order_by_arg() do
    quote do
      Absinthe.Schema.Notation.arg(:order_by, list_of(:order_by_field))
    end
  end

  defp add_query_mutation(env, field, mutate_fn) do
    set_module_attr({field, mutate_fn}, :query_mutations, env)
  end

  defp add_result_mutation(env, field, mutate_fn) do
    set_module_attr({field, mutate_fn}, :result_mutations, env)
  end

  defmacro mutate_query(field, mutate_fn) do
    add_query_mutation(__CALLER__, field, mutate_fn)
  end

  defmacro mutate_query(mutate_fn) do
    add_query_mutation(__CALLER__, :__global, mutate_fn)
  end

  defmacro mutate_result(field, mutate_fn) do
    add_result_mutation(__CALLER__, field, mutate_fn)
  end

  defmacro mutate_result(mutate_fn) do
    add_result_mutation(__CALLER__, :__global, mutate_fn)
  end

  defmacro filters(field, filter_list) do
    f = Enum.map(filter_list, fn f -> add_filter(__CALLER__, field, f) end)

    quote do
      unquote(f)
    end
  end

  defmacro filters(field, type, filter_list) do
    f = Enum.map(filter_list, fn f -> add_filter(__CALLER__, field, f, type) end)

    quote do
      unquote(f)
    end
  end

  defp add_filter(env, field, filter, type \\ nil) do
    argument_name = EctoGQL.Filters.Helpers.filter_name(filter, field)
    type = type || get_ecto_type(get_schema(env), field)

    if !type do
      raise "Field #{inspect(field)} does not exist in the database schema. Make sure the field exists and is not virtual."
    end

    handler = EctoGQL.Arguments.create_argument_handler(argument_name, filter, field)
    set_module_attr({argument_name, handler}, :argument_handlers, env)

    quote do
      Absinthe.Schema.Notation.arg(unquote(argument_name), unquote(type))
    end
  end

  defmacro __before_compile__(env) do
    query_mutations =
      get_module_attr(env, :query_mutations, [])
      |> Enum.group_by(fn {key, _value} -> key end, fn {_key, value} -> value end)
      |> Map.to_list()

    result_mutations =
      get_module_attr(env, :result_mutations, [])
      |> Enum.group_by(fn {key, _value} -> key end, fn {_key, value} -> value end)
      |> Map.to_list()

    argument_handlers =
      get_module_attr(env, :argument_handlers, [])
      # TODO: this is only needed because we run filters multiple times when creating connections
      # field etc... The problem should actually be fixed there not here
      |> Enum.dedup_by(fn {arg, _} -> arg end)
      |> Enum.map(fn {_, handler} -> handler end)

    quote do
      def resolve_all(parent, args, resolution) do
        EctoGQL.Resolver.resolve_multiple(__MODULE__, parent, args, resolution)
      end

      def resolve_single(parent, args, resolution) do
        EctoGQL.Resolver.resolve_single(__MODULE__, parent, args, resolution)
      end

      def resolve_connection(parent, args, resolution) do
        EctoGQL.Resolver.resolve_connection(__MODULE__, parent, args, resolution)
      end

      def __schema__() do
        @schema
      end

      def __query_mutations__() do
        %{unquote_splicing(query_mutations)}
      end

      def __result_mutations__() do
        %{unquote_splicing(result_mutations)}
      end

      unquote(argument_handlers)

      def handle_argument(_, query, _) do
        query
      end
    end
  end
end

defmodule EctoGQL.Arguments do
  # Make sure filters are compiled before this file so we can reference them at compile-time
  require EctoGQL.Filters

  def create_argument_handler(argument_name, filter, field) do
    quote do
      def handle_argument(unquote(argument_name), query, value) do
        unquote(filter)(query, unquote(field), value)
      end
    end
  end
end

defmodule EctoGQL.Helpers do
  require Absinthe.Schema.Notation

  def get_module_attr(env, name, default \\ nil) do
    Module.get_attribute(env.module, name, default)
  end

  def get_schema(env) do
    get_module_attr(env, :schema)
  end

  def set_module_attr(value, name, env) do
    Module.put_attribute(env.module, name, value)
  end

  def get_gql_type(schema, name) do
    schema.__changeset__()
    |> Map.fetch!(name)
    |> case do
      :map -> :json
      # Macro.escape since this value will be used in a quoted expression
      {:array, type} -> Macro.escape(Absinthe.Schema.Notation.list_of(type))
      other -> other
    end
  end

  def get_ecto_type(schema, name) do
    schema.__schema__(:type, name)
  end

  def has_selection(resolution, path) do
    case find_selection_by_path(resolution, path) do
      {:ok, _selection} ->
        true

      {:error, _} ->
        false
    end
  end

  def selection_id(selection) do
    selection.schema_node.identifier
  end

  def find_selection_by_path(resolution, path) do
    find_selection(resolution.definition, path)
  end

  defp find_selection(definition, []) do
    {:ok, definition}
  end

  defp find_selection(definition, [field | path]) do
    Enum.find(definition.selections, fn selection -> selection_id(selection) == field end)
    |> case do
      nil ->
        {:error, "Not found"}

      definition ->
        find_selection(definition, path)
    end
  end
end

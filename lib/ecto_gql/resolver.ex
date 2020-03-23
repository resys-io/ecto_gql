defmodule EctoGQL.Resolver do
  import EctoGQL.Helpers
  import Ecto.Query, warn: false

  defp ensure_root_query(resolution) do
    if resolution.parent_type.identifier != :query do
      # TODO: need to figure out what parent_type would be if not dealing with root query
      # need to handle this situation correctly
      raise "Not root query!"
    end
  end

  def resolve(type, module, parent, args, resolution) do
    ensure_root_query(resolution)

    case run_prechecks(module, parent, args, resolution) do
      {:ok, _value} = value ->
        value

      {:error, _message} = value ->
        value

      :continue ->
        fetch_results(type, module, parent, args, resolution)
    end
  end

  defp fetch_results(:multiple, module, parent, args, resolution) do
    child_fields =
      Absinthe.Resolution.project(resolution)
      |> Enum.map(&selection_id/1)

    setup_query(child_fields, module, parent, args, resolution)
    |> module.__repo__().all()
    |> Enum.map(&run_mutations(&1, child_fields, module))
    |> send_result(:ok)
  end

  defp fetch_results(:single, module, parent, args, resolution) do
    child_fields =
      Absinthe.Resolution.project(resolution)
      |> Enum.map(&selection_id/1)

    setup_query(child_fields, module, parent, args, resolution)
    |> limit(2)
    |> module.__repo__().all()
    |> case do
      [] -> {:ok, nil}
      [result] -> {:ok, run_mutations(result, child_fields, module)}
      _ -> {:error, "Multiple results found!"}
    end
  end

  defp fetch_results(:connection, module, parent, args, resolution) do
    child_fields =
      case find_selection_by_path(resolution, [:edges, :node]) do
        {:error, _} -> []
        {:ok, field} -> Enum.map(field.selections, &selection_id/1)
      end

    query = setup_query(child_fields, module, parent, args, resolution)

    query
    # TODO: configurable repo options (maximum_limit, limit etc)
    # TODO: clean this up... this does not seem like the spot to set these settings
    |> EctoGQL.Connection.from_query(module.__repo__(), args,
      maximum_limit: 500,
      limit: args[:first] || 20,
      after: args[:after],
      before: args[:before],
      cursor_fields: EctoGQL.OrderBy.infer_order_by(query),
      include_total_count: has_selection(resolution, [:page_info, :total_count]),
      total_count_limit: 10_000
    )
    |> run_edges_mutations(child_fields, module)
    |> send_result(:ok)
  end

  defp send_result(result, type) do
    {type, result}
  end

  defp run_edges_mutations(result, child_fields, module) do
    Map.update!(result, :edges, fn edges ->
      Enum.map(edges, fn edge ->
        Map.put(edge, :node, run_mutations(edge.node, child_fields, module))
      end)
    end)
  end

  defp setup_query(child_fields, module, parent, args, resolution) do
    query =
      module.__schema__()
      |> apply_order_by(module, args[:order_by])

    Enum.reduce(child_fields, query, fn field, query ->
      Map.get(module.__query_mutations__(), field, [])
      |> Enum.reduce(query, &call_query_mutator(&1, &2, parent, args, resolution))
    end)
    |> global_query_mutations(module, parent, args, resolution)
    |> handle_query_arguments(module, parent, args, resolution)
  end

  defp apply_order_by(module, query, nil) do
    default_order_args =
      for key <- module.__schema__(:primary_key) do
        {:desc, key}
      end

    order_by(query, ^default_order_args)
  end

  defp apply_order_by(module, query, []) do
    apply_order_by(module, query, nil)
  end

  defp apply_order_by(_module, query, order_bys) do
    order_bys =
      Enum.map(order_bys, fn %{field: field, direction: direction} ->
        {direction, field |> Macro.underscore() |> String.to_existing_atom()}
      end)

    order_by(query, ^order_bys)
  end

  defp global_query_mutations(query, module, parent, args, resolution) do
    Map.get(module.__query_mutations__(), :__global, [])
    |> Enum.reduce(query, &call_query_mutator(&1, &2, parent, args, resolution))
  end

  defp handle_query_arguments(query, module, _parent, args, _resolution) do
    Enum.reduce(args, query, fn {name, value}, query ->
      module.handle_argument(name, query, value)
    end)
  end

  defp run_mutations(result, child_fields, module) do
    result
    |> run_global_mutations(module)
    |> run_field_mutations(child_fields, module)
  end

  defp run_prechecks(module, parent, args, resolution) do
    module.__prechecks__()
    |> handle_prechecks(module, parent, args, resolution)
  end

  defp handle_prechecks([check | rest_checks], module, parent, args, resolution) do
    case check.(parent, args, resolution) do
      :continue ->
        handle_prechecks(rest_checks, module, parent, args, resolution)

      other ->
        other
    end
  end

  defp handle_prechecks([], _module, _parent, _args, _resolution) do
    :continue
  end

  defp run_global_mutations(result, module) do
    module.__result_mutations__()
    |> Map.get(:__global, [])
    |> Enum.reduce(result, fn mutator, result -> mutator.(result) end)
  end

  defp run_field_mutations(result, child_fields, module) do
    Enum.reduce(child_fields, result, fn field, result ->
      Map.get(module.__result_mutations__(), field, [])
      |> Enum.reduce(result, fn mutator, result -> mutator.(result) end)
    end)
  end

  defp call_query_mutator(mutator, query, _parent, _args, _resolution)
       when is_function(mutator, 1) do
    mutator.(query)
  end

  defp call_query_mutator(mutator, query, _parent, args, _resolution)
       when is_function(mutator, 2) do
    mutator.(query, args)
  end

  defp call_query_mutator(mutator, query, parent, args, resolution)
       when is_function(mutator, 4) do
    mutator.(query, parent, args, resolution)
  end
end

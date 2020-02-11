defmodule EctoGQL.Connection do
  require Ecto.Query
  require Logger

  def from_query(query, repo, _args, opts \\ []) do
    query
    |> Paginator.paginate(opts, repo, [])
    |> build_response(opts)
  end

  def build_response(page_data, opts) do
    items = page_data.entries
    {edges, first, last} = build_cursors(items, opts)

    page_info = %{
      start_cursor: first,
      end_cursor: last,
      has_previous_page: page_data.metadata.before != nil,
      has_next_page: page_data.metadata.after != nil,
      total_count: page_data.metadata.total_count
    }

    %{edges: edges, page_info: page_info}
  end

  defp build_cursors([], _opts), do: {[], nil, nil}

  defp build_cursors([item | items], opts) do
    first = Paginator.cursor_for_record(item, opts[:cursor_fields])
    edge = build_edge(item, first)
    {edges, last} = do_build_cursors(opts, items, [edge], first)
    {edges, first, last}
  end

  defp do_build_cursors(_opts, [], edges, last), do: {Enum.reverse(edges), last}

  defp do_build_cursors(opts, [item | rest], edges, _last) do
    cursor = Paginator.cursor_for_record(item, opts[:cursor_fields])
    edge = build_edge(item, cursor)
    do_build_cursors(opts, rest, [edge | edges], cursor)
  end

  defp build_edge({item, args}, cursor) do
    args
    |> Enum.flat_map(fn
      {key, _} when key in [:cursor, :node] ->
        Logger.warn("Ignoring additional #{key} provided on edge (overriding is not allowed)")
        []

      {key, val} ->
        [{key, val}]
    end)
    |> Enum.into(build_edge(item, cursor))
  end

  defp build_edge(item, cursor) do
    %{
      node: item,
      cursor: cursor
    }
  end
end

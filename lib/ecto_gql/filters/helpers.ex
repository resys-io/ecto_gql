defmodule EctoGQL.Filters.Helpers do
  def filter_name(:equals, field) do
    field
  end

  def filter_name(filter, field) do
    (Atom.to_string(field) <> "_" <> Atom.to_string(filter))
    |> String.to_atom()
  end
end

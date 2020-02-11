defmodule EctoGQL.Filters do
  import Ecto.Query

  def equals(query, field, value) do
    where(query, ^[{field, value}])
  end

  def contains(query, field, value) do
    from q in query,
      where: ilike(field(q, ^field), ^"%#{value}%")
  end
end

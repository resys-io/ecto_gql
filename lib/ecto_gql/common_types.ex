defmodule EctoGQL.Types do
  use Absinthe.Schema.Notation

  object :page_info do
    @desc "When paginating backwards, are there more items?"
    field(:has_previous_page, non_null(:boolean))

    @desc "When paginating forwards, are there more items?"
    field(:has_next_page, non_null(:boolean))

    @desc "When paginating backwards, the cursor to continue."
    field(:start_cursor, :string)

    @desc "When paginating forwards, the cursor to continue."
    field(:end_cursor, :string)

    @desc "Total count of available items"
    field(:total_count, :integer)
  end

  enum :order_by_direction do
    description("The direction for the ordering")

    value(:asc, description: "In ascending order")
    value(:desc, description: "In descending order")
  end

  input_object :order_by_field do
    field(:field, non_null(:string))
    field(:direction, non_null(:order_by_direction))
  end
end

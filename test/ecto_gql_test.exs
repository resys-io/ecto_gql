defmodule EctoGQLTest do
  use ExUnit.Case
  doctest EctoGQL

  # TODO: test that each raw graphql query string actually corresponds to correct resolve functions
  # 1. single -> resolve_single
  # 2. multiple -> resolve_all
  # 3. connection -> resolve_connection
  # This allows us to depend on the corresponding resolve functions in other tests

  # TODO: test raw graphql query strings

  test "denies access" do
    defmodule AccessModel do
      use Ecto.Schema

      schema "user" do
        field(:is_admin, :boolean)
      end
    end

    defmodule AccessTest do
      use EctoGQL, schema: AccessModel, singular: :user, plural: :users

      object do
        field(:is_admin)
        has_access(&check_user_permissions/3)
      end

      def check_user_permissions(_parent, _args, %{context: %{user: user}}) do
        case user.role do
          :admin ->
            true

          :user ->
            false
        end
      end
    end

    resolution = %{parent_type: %{identifier: :query}, context: %{user: %{role: :user}}}

    # TODO: test all resolve functions.. or use some other way to do this
    assert AccessTest.resolve_all(nil, %{}, resolution) == {:error, "Access is not allowed!"}
    # TODO: test that function returns normally if user role is :admin
  end
end

require "cases/helper"
require "active_model/attributes"

module ActiveModel
  class AttributesTest < ActiveModel::TestCase
    class ModelForAttributesTest
      include ActiveModel::Model
      include ActiveModel::Dirty
      include ActiveModel::Attributes

      attribute :integer_field, :integer
      attribute :string_field, :string
      attribute :decimal_field, :decimal
      attribute :string_with_default, :string, default: "default string"
      attribute :date_field, :string, default: -> { Date.new(2016, 1, 1) }
      attribute :boolean_field, :boolean
    end

    class ChildModelForAttributesTest < ModelForAttributesTest
    end

    class GrandchildModelForAttributesTest < ChildModelForAttributesTest
      attribute :integer_field, :string
    end

    test "properties assignment" do
      data = ModelForAttributesTest.new(
        integer_field: "2.3",
        string_field: "Rails FTW",
        decimal_field: "12.3",
        boolean_field: "0"
      )

      assert_equal 2, data.integer_field
      assert_equal "Rails FTW", data.string_field
      assert_equal BigDecimal.new("12.3"), data.decimal_field
      assert_equal "default string", data.string_with_default
      assert_equal Date.new(2016, 1, 1), data.date_field
      assert_equal false, data.boolean_field

      data.integer_field = 10
      data.string_with_default = nil
      data.boolean_field = "1"

      assert_equal 10, data.integer_field
      assert_equal nil, data.string_with_default
      assert_equal true, data.boolean_field
    end

    test "nonexistent attribute" do
      assert_raise ActiveModel::UnknownAttributeError do
        ModelForAttributesTest.new(nonexistent: "nonexistent")
      end
    end

    test "children inherit attributes" do
      data = ChildModelForAttributesTest.new(integer_field: "4.4")

      assert_equal 4, data.integer_field
    end

    test "children can override parents" do
      data = GrandchildModelForAttributesTest.new(integer_field: "4.4")

      assert_equal "4.4", data.integer_field
    end

    test "attributes are registered with passed options" do
      expected_attributes_keys = [
        :integer_field,
        :string_field,
        :decimal_field,
        :string_with_default,
        :date_field,
        :boolean_field
      ]
      registry = GrandchildModelForAttributesTest.attributes_registry

      assert_equal expected_attributes_keys, registry.keys
      assert_equal [:string, {}], registry[:integer_field]
      assert_equal [:decimal, {}], registry[:decimal_field]
      assert_equal [:string, { default: "default string" }], registry[:string_with_default]
      assert_equal Date.new(2016, 1, 1), registry[:date_field].last[:default].call
    end
  end
end

require "abstract_unit"
require "active_support/core_ext/module"

module One
  Constant1 = "Hello World"
  Constant2 = "What's up?"
end

class Ab
  include One
  Constant1 = "Hello World" # Will have different object id than One::Constant1
  Constant3 = "Goodbye World"
end

module Yz
  module Zy
    class Cd
      include One
    end
  end
end

Somewhere = Struct.new(:street, :city) do
  attr_accessor :name
end

class Someone < Struct.new(:name, :place)
  delegate :street, :city, :to_f, to: :place
  delegate :name=, to: :place, prefix: true
  delegate :upcase, to: "place.city"
  delegate :table_name, to: :class
  delegate :table_name, to: :class, prefix: true

  def self.table_name
    "some_table"
  end

  FAILED_DELEGATE_LINE = __LINE__ + 1
  delegate :foo, to: :place

  FAILED_DELEGATE_LINE_2 = __LINE__ + 1
  delegate :bar, to: :place, allow_nil: true

  private

    def private_name
      "Private"
    end
end

Invoice   = Struct.new(:client) do
  delegate :street, :city, :name, to: :client, prefix: true
  delegate :street, :city, :name, to: :client, prefix: :customer
end

Project   = Struct.new(:description, :person) do
  delegate :name, to: :person, allow_nil: true
  delegate :to_f, to: :description, allow_nil: true
end

Developer = Struct.new(:client) do
  delegate :name, to: :client, prefix: nil
end

Event = Struct.new(:case) do
  delegate :foo, to: :case
end

Tester = Struct.new(:client) do
  delegate :name, to: :client, prefix: false

  def foo; 1; end
end

Product = Struct.new(:name) do
  delegate :name, to: :manufacturer, prefix: true
  delegate :name, to: :type, prefix: true

  def manufacturer
    @manufacturer ||= begin
      nil.unknown_method
    end
  end

  def type
    @type ||= begin
      nil.type_name
    end
  end
end

DecoratedTester = Struct.new(:client) do
  delegate_missing_to :client
end

class DecoratedReserved
  delegate_missing_to :case

  attr_reader :case

  def initialize(kase)
    @case = kase
  end
end

class Block
  def hello?
    true
  end
end

HasBlock = Struct.new(:block) do
  delegate :hello?, to: :block
end

class ParameterSet
  delegate :[], :[]=, to: :@params

  def initialize
    @params = { foo: "bar" }
  end
end

class Name
  delegate :upcase, to: :@full_name

  def initialize(first, last)
    @full_name = "#{first} #{last}"
  end
end

class SideEffect
  attr_reader :ints

  delegate :to_i, to: :shift, allow_nil: true
  delegate :to_s, to: :shift

  def initialize
    @ints = [1, 2, 3]
  end

  def shift
    @ints.shift
  end
end

class ModuleTest < ActiveSupport::TestCase
  def setup
    @david = Someone.new("David", Somewhere.new("Paulina", "Chicago"))
  end

  def test_delegation_to_methods
    assert_equal "Paulina", @david.street
    assert_equal "Chicago", @david.city
  end

  def test_delegation_to_assignment_method
    @david.place_name = "Fred"
    assert_equal "Fred", @david.place.name
  end

  def test_delegation_to_index_get_method
    @params = ParameterSet.new
    assert_equal "bar", @params[:foo]
  end

  def test_delegation_to_index_set_method
    @params = ParameterSet.new
    @params[:foo] = "baz"
    assert_equal "baz", @params[:foo]
  end

  def test_delegation_down_hierarchy
    assert_equal "CHICAGO", @david.upcase
  end

  def test_delegation_to_instance_variable
    david = Name.new("David", "Hansson")
    assert_equal "DAVID HANSSON", david.upcase
  end

  def test_delegation_to_class_method
    assert_equal "some_table", @david.table_name
    assert_equal "some_table", @david.class_table_name
  end

  def test_missing_delegation_target
    assert_raise(ArgumentError) do
      Name.send :delegate, :nowhere
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :noplace, tos: :hollywood
    end
  end

  def test_delegation_target_when_prefix_is_true
    assert_nothing_raised do
      Name.send :delegate, :go, to: :you, prefix: true
    end
    assert_nothing_raised do
      Name.send :delegate, :go, to: :_you, prefix: true
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :go, to: :You, prefix: true
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :go, to: :@you, prefix: true
    end
  end

  def test_delegation_prefix
    invoice = Invoice.new(@david)
    assert_equal invoice.client_name, "David"
    assert_equal invoice.client_street, "Paulina"
    assert_equal invoice.client_city, "Chicago"
  end

  def test_delegation_custom_prefix
    invoice = Invoice.new(@david)
    assert_equal invoice.customer_name, "David"
    assert_equal invoice.customer_street, "Paulina"
    assert_equal invoice.customer_city, "Chicago"
  end

  def test_delegation_prefix_with_nil_or_false
    assert_equal Developer.new(@david).name, "David"
    assert_equal Tester.new(@david).name, "David"
  end

  def test_delegation_prefix_with_instance_variable
    assert_raise ArgumentError do
      Class.new do
        def initialize(client)
          @client = client
        end
        delegate :name, :address, to: :@client, prefix: true
      end
    end
  end

  def test_delegation_with_allow_nil
    rails = Project.new("Rails", Someone.new("David"))
    assert_equal rails.name, "David"
  end

  def test_delegation_with_allow_nil_and_nil_value
    rails = Project.new("Rails")
    assert_nil rails.name
  end

  # Ensures with check for nil, not for a falseish target.
  def test_delegation_with_allow_nil_and_false_value
    project = Project.new(false, false)
    assert_raise(NoMethodError) { project.name }
  end

  def test_delegation_with_allow_nil_and_invalid_value
    rails = Project.new("Rails", "David")
    assert_raise(NoMethodError) { rails.name }
  end

  def test_delegation_with_allow_nil_and_nil_value_and_prefix
    Project.class_eval do
      delegate :name, to: :person, allow_nil: true, prefix: true
    end
    rails = Project.new("Rails")
    assert_nil rails.person_name
  end

  def test_delegation_without_allow_nil_and_nil_value
    david = Someone.new("David")
    assert_raise(Module::DelegationError) { david.street }
  end

  def test_delegation_to_method_that_exists_on_nil
    nil_person = Someone.new(nil)
    assert_equal 0.0, nil_person.to_f
  end

  def test_delegation_to_method_that_exists_on_nil_when_allowing_nil
    nil_project = Project.new(nil)
    assert_equal 0.0, nil_project.to_f
  end

  def test_delegation_does_not_raise_error_when_removing_singleton_instance_methods
    parent = Class.new do
      def self.parent_method; end
    end

    assert_nothing_raised do
      Class.new(parent) do
        class << self
          delegate :parent_method, to: :superclass
        end
      end
    end
  end

  def test_delegation_line_number
    _, line = Someone.instance_method(:foo).source_location
    assert_equal Someone::FAILED_DELEGATE_LINE, line
  end

  def test_delegate_line_with_nil
    _, line = Someone.instance_method(:bar).source_location
    assert_equal Someone::FAILED_DELEGATE_LINE_2, line
  end

  def test_delegation_exception_backtrace
    someone = Someone.new("foo", "bar")
    someone.foo
  rescue NoMethodError => e
    file_and_line = "#{__FILE__}:#{Someone::FAILED_DELEGATE_LINE}"
    # We can't simply check the first line of the backtrace, because JRuby reports the call to __send__ in the backtrace.
    assert e.backtrace.any? { |a| a.include?(file_and_line) },
           "[#{e.backtrace.inspect}] did not include [#{file_and_line}]"
  end

  def test_delegation_exception_backtrace_with_allow_nil
    someone = Someone.new("foo", "bar")
    someone.bar
  rescue NoMethodError => e
    file_and_line = "#{__FILE__}:#{Someone::FAILED_DELEGATE_LINE_2}"
    # We can't simply check the first line of the backtrace, because JRuby reports the call to __send__ in the backtrace.
    assert e.backtrace.any? { |a| a.include?(file_and_line) },
           "[#{e.backtrace.inspect}] did not include [#{file_and_line}]"
  end

  def test_delegation_invokes_the_target_exactly_once
    se = SideEffect.new

    assert_equal 1, se.to_i
    assert_equal [2, 3], se.ints

    assert_equal "2", se.to_s
    assert_equal [3], se.ints
  end

  def test_delegation_doesnt_mask_nested_no_method_error_on_nil_receiver
    product = Product.new("Widget")

    # Nested NoMethodError is a different name from the delegation
    assert_raise(NoMethodError) { product.manufacturer_name }

    # Nested NoMethodError is the same name as the delegation
    assert_raise(NoMethodError) { product.type_name }
  end

  def test_delegation_with_method_arguments
    has_block = HasBlock.new(Block.new)
    assert has_block.hello?
  end

  def test_delegate_to_missing_with_method
    assert_equal "David", DecoratedTester.new(@david).name
  end

  def test_delegate_to_missing_with_reserved_methods
    assert_equal "David", DecoratedReserved.new(@david).name
  end

  def test_delegate_to_missing_does_not_delegate_to_private_methods
    e = assert_raises(NoMethodError) do
      DecoratedReserved.new(@david).private_name
    end

    assert_match(/undefined method `private_name' for/, e.message)
  end

  def test_delegate_to_missing_does_not_delegate_to_fake_methods
    e = assert_raises(NoMethodError) do
      DecoratedReserved.new(@david).my_fake_method
    end

    assert_match(/undefined method `my_fake_method' for/, e.message)
  end

  def test_parent
    assert_equal Yz::Zy, Yz::Zy::Cd.parent
    assert_equal Yz, Yz::Zy.parent
    assert_equal Object, Yz.parent
  end

  def test_parents
    assert_equal [Yz::Zy, Yz, Object], Yz::Zy::Cd.parents
    assert_equal [Yz, Object], Yz::Zy.parents
  end

  def test_local_constants
    ActiveSupport::Deprecation.silence do
      assert_equal %w(Constant1 Constant3), Ab.local_constants.sort.map(&:to_s)
    end
  end

  def test_local_constants_is_deprecated
    assert_deprecated { Ab.local_constants.sort.map(&:to_s) }
  end
end

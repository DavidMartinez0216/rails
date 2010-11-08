require 'abstract_unit'
require 'active_support/core_ext/kernel/reporting'

class AssertDifferenceTest < ActiveSupport::TestCase
  def setup
    @object = Class.new do
      attr_accessor :num
      def increment
        self.num += 1
      end

      def decrement
        self.num -= 1
      end
    end.new
    @object.num = 0
  end

  if lambda { }.respond_to?(:binding)
    def test_assert_no_difference
      assert_no_difference '@object.num' do
        # ...
      end
    end

    def test_assert_difference
      assert_difference '@object.num', +1 do
        @object.increment
      end
    end

    def test_assert_difference_with_implicit_difference
      assert_difference '@object.num' do
        @object.increment
      end
    end

    def test_arbitrary_expression
      assert_difference '@object.num + 1', +2 do
        @object.increment
        @object.increment
      end
    end

    def test_negative_differences
      assert_difference '@object.num', -1 do
        @object.decrement
      end
    end

    def test_expression_is_evaluated_in_the_appropriate_scope
      silence_warnings do
        local_scope = 'foo'
        assert_difference('local_scope; @object.num') { @object.increment }
      end
    end

    def test_array_of_expressions
      assert_difference [ '@object.num', '@object.num + 1' ], +1 do
        @object.increment
      end
    end

    def test_array_of_expressions_identify_failure
      assert_difference ['@object.num', '1 + 1'] do
        @object.increment
      end
      fail 'should not get to here'
    rescue Exception => e
      assert_match(/didn't change by/, e.message)
      assert_match(/expected but was/, e.message)
    end

    def test_array_of_expressions_identify_failure_when_message_provided
      assert_difference ['@object.num', '1 + 1'], 1, 'something went wrong' do
        @object.increment
      end
      fail 'should not get to here'
    rescue Exception => e
      assert_match(/something went wrong/, e.message)
      assert_match(/didn't change by/, e.message)
      assert_match(/expected but was/, e.message)
    end
  else
    def default_test; end
  end
end

class AssertBlankTest < ActiveSupport::TestCase
  BLANK = [ EmptyTrue.new, nil, false, '', '   ', "  \n\t  \r ", [], {} ]
  NOT_BLANK = [ EmptyFalse.new, Object.new, true, 0, 1, 'x', [nil], { nil => 0 } ]

  def test_assert_blank_true
    BLANK.each { |v| assert_blank v }
  end

  def test_assert_blank_false
    NOT_BLANK.each { |v|
      begin
        assert_blank v
        fail 'should not get to here'
      rescue Exception => e
        assert_match(/is not blank/, e.message)
      end
    }
  end
end

class AssertPresentTest < ActiveSupport::TestCase
  BLANK = [ EmptyTrue.new, nil, false, '', '   ', "  \n\t  \r ", [], {} ]
  NOT_BLANK = [ EmptyFalse.new, Object.new, true, 0, 1, 'x', [nil], { nil => 0 } ]

  def test_assert_blank_true
    NOT_BLANK.each { |v| assert_present v }
  end

  def test_assert_blank_false
    BLANK.each { |v|
      begin
        assert_present v
        fail 'should not get to here'
      rescue Exception => e
        assert_match(/is blank/, e.message)
      end
    }
  end
end

class AssertValidTest < ActiveSupport::TestCase
  VALID = Class.new do
    def valid?
      true
    end
  end.new

  INVALID = Class.new do
    def valid?
      false
    end
  end.new
  

  def test_assert_valid_true
    assert_valid VALID
  end

  def test_assert_valid_false
    begin
      assert_valid INVALID
      fail "should not get to here"
    rescue Exception => e
      assert_match(/is not valid/, e.message) 
    end
  end

  def test_assert_valid_false_with_custom_message
    begin
      assert_valid INVALID, "custom message"
      fail "should not get to here"
    rescue Exception => e
      assert_match(/custom message/, e.message) 
    end
  end
end

class AlsoDoingNothingTest < ActiveSupport::TestCase
end

# Setup and teardown callbacks.
class SetupAndTeardownTest < ActiveSupport::TestCase
  setup :reset_callback_record, :foo
  teardown :foo, :sentinel, :foo

  def test_inherited_setup_callbacks
    assert_equal [:reset_callback_record, :foo], self.class._setup_callbacks.map(&:raw_filter)
    assert_equal [:foo], @called_back
    assert_equal [:foo, :sentinel, :foo], self.class._teardown_callbacks.map(&:raw_filter)
  end

  def setup
  end

  def teardown
  end

  protected

    def reset_callback_record
      @called_back = []
    end

    def foo
      @called_back << :foo
    end

    def sentinel
      assert_equal [:foo, :foo], @called_back
    end
end


class SubclassSetupAndTeardownTest < SetupAndTeardownTest
  setup :bar
  teardown :bar

  def test_inherited_setup_callbacks
    assert_equal [:reset_callback_record, :foo, :bar], self.class._setup_callbacks.map(&:raw_filter)
    assert_equal [:foo, :bar], @called_back
    assert_equal [:foo, :sentinel, :foo, :bar], self.class._teardown_callbacks.map(&:raw_filter)
  end

  protected
    def bar
      @called_back << :bar
    end

    def sentinel
      assert_equal [:foo, :bar, :bar, :foo], @called_back
    end
end

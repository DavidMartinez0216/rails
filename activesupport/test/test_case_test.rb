require 'abstract_unit'

module ActiveSupport
  class TestCaseTest < ::Test::Unit::TestCase

    if defined?(MiniTest::Assertions) && TestCase < MiniTest::Assertions
      
      class FakeRunner
        attr_reader :puked

        def initialize
          @puked = []
        end

        def puke(klass, name, e)
          @puked << [klass, name, e]
        end

        def options
          nil
        end
      end
      
      def test_callback_with_exception
        test_case = Class.new(TestCase) do
          setup :bad_callback
          def bad_callback; raise 'oh noes' end
          def test_true; assert true end
        end

        test_name = 'test_true'
        runner = FakeRunner.new

        test = test_case.new test_name
        test.run runner
        klass, name, exception = *runner.puked.first

        assert_equal test_case, klass
        assert_equal test_name, name
        assert_equal 'oh noes', exception.message
      end

      def test_teardown_callback_with_exception
        test_case = Class.new(TestCase) do
          teardown :bad_callback
          def bad_callback; raise 'oh noes' end
          def test_true; assert true end
        end

        test_name = 'test_true'
        runner = FakeRunner.new

        test = test_case.new test_name
        test.run runner
        klass, name, exception = *runner.puked.first

        assert_equal test_case, klass
        assert_equal test_name, name
        assert_equal 'oh noes', exception.message
      end
      
    else # Test::Unit
      
      def test_callback_with_exception
        test_case = Class.new(TestCase) do
          setup :bad_callback
          def bad_callback; raise 'oh noes' end
          def test_true; assert true end
        end

        result = Test::Unit::TestResult.new
        test = test_case.new "test_true"
        test.run(result) do |channel, value|
          assert channel; assert value # don't care really
        end
        
        assert ! result.passed?
        assert_equal 1, result.error_count
        error = get_test_result_errors(result).first
        assert_equal error.test_name, "test_true()"
        assert_equal 'oh noes', error.exception.message
      end

      def test_teardown_callback_with_exception
        test_case = Class.new(TestCase) do
          teardown :bad_callback
          def bad_callback; raise 'oh noes' end
          def test_true; assert true end
        end

        result = Test::Unit::TestResult.new
        test = test_case.new "test_true"
        test.run(result) do |channel, value|
          assert channel; assert value # don't care really
        end

        assert ! result.passed?
        assert_equal 1, result.error_count
        error = get_test_result_errors(result).first
        assert_equal error.test_name, "test_true()"
        assert_equal 'oh noes', error.exception.message
      end

      def test_yields_test_started_and_finished
        test_case = Class.new(TestCase) do
          def test_true; assert true end
        end

        result = Test::Unit::TestResult.new
        test = test_case.new "test_true"
        yields = []
        test.run(result) do |channel, value|
          yields << [ channel, value ]
        end

        if new_test_unit?
          assert_equal 4, yields.size
          assert_equal Test::Unit::TestCase::STARTED, yields[0][0]
          assert_equal 'test_true()', yields[0][1]
          assert_equal Test::Unit::TestCase::FINISHED, yields[2][0]
          assert_equal 'test_true()', yields[2][1]
        else
          assert_equal 2, yields.size
          assert_equal Test::Unit::TestCase::STARTED, yields[0][0]
          assert_equal 'test_true()', yields[0][1]
          assert_equal Test::Unit::TestCase::FINISHED, yields[1][0]
          assert_equal 'test_true()', yields[1][1]
        end
      end
      
      def test_yields_test_started_and_finished_with_bad_callbacks
        test_case = Class.new(TestCase) do
          setup :bad_callback
          teardown :bad_callback
          def bad_callback; raise 'oh noes' end
          def test_true; assert true end
        end

        result = Test::Unit::TestResult.new
        test = test_case.new "test_true"
        yields = []
        test.run(result) do |channel, value|
          yields << [ channel, value ]
        end

        if new_test_unit?
          assert_equal 4, yields.size
          assert_equal Test::Unit::TestCase::STARTED, yields[0][0]
          assert_equal 'test_true()', yields[0][1]
          assert_equal Test::Unit::TestCase::FINISHED, yields[2][0]
          assert_equal 'test_true()', yields[2][1]
        else
          assert_equal 2, yields.size
          assert_equal Test::Unit::TestCase::STARTED, yields[0][0]
          assert_equal 'test_true()', yields[0][1]
          assert_equal Test::Unit::TestCase::FINISHED, yields[1][0]
          assert_equal 'test_true()', yields[1][1]
        end
      end
      
      def test_mocha_verify
        test_case = Class.new(TestCase) do
          def test_mocha_failure
            Object.new.expects(:foo)
          end
        end

        result = Test::Unit::TestResult.new
        test = test_case.new "test_mocha_failure"
        test.run(result) { |channel, value| channel && value }

        assert ! result.passed?
        assert_equal 1, result.failure_count
        failure = get_test_result_failures(result).first
        assert_equal failure.test_name, "test_mocha_failure()"
        
        mocha_failure = 
          "not all expectations were satisfied\nunsatisfied expectations:\n- expected exactly once, not yet invoked"
        assert_equal mocha_failure, failure.message[0,mocha_failure.size]
      end

      @@moched_object = nil
      def self.moched_object; @@moched_object; end
      
      def test_mocha_teardown
        @@moched_object = Object.new
        test_case = Class.new(TestCase) do
          def test_mocha_success
            o = ActiveSupport::TestCaseTest.moched_object
            o.expects(:hash).once
            o.hash
          end
        end

        result = Test::Unit::TestResult.new
        test = test_case.new "test_mocha_success"
        test.run(result) { |channel, value| channel && value }

        assert result.passed?
        assert_nothing_raised do
          @@moched_object.hash
        end
      ensure
        @@moched_object = nil
      end
      
      private
      
        def get_test_result_errors(test_result)
          test_result.respond_to?(:errors) ? 
            test_result.errors : # Test::Unit 2.x
              test_result.instance_variable_get(:'@errors') # classic Test::Unit
        end

        def get_test_result_failures(test_result)
          test_result.respond_to?(:failures) ? 
            test_result.failures : # Test::Unit 2.x
              test_result.instance_variable_get(:'@failures') # classic Test::Unit
        end
        
        def new_test_unit?
          Test::Unit::TestResult.new.respond_to?(:faults)
        end
        
    end
    
  end
end

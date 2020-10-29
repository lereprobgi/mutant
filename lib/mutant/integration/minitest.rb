# frozen_string_literal: true

# Note: The minitest integration was sponsored by [Arkency](https://arkency.com/).
# Without their support this integration would not exist.

require 'minitest'
require 'mutant/minitest/coverage'

module Minitest
  # Prevent autorun from running tests when the VM closes
  #
  # Mutant needs control about the exit status of the VM and
  # the moment of test execution
  #
  # @api private
  #
  # @return [nil]
  def self.autorun; end
end # Minitest

module Mutant
  class Integration
    # Minitest integration
    class Minitest < self
      TEST_FILE_PATTERN     = './test/**/{test_*,*_test}.rb'
      IDENTIFICATION_FORMAT = 'minitest:%s#%s'

      private_constant(*constants(false))

      # Compose a runnable with test method
      #
      # This looks actually like a missing object on minitest implementation.
      class TestCase
        include Adamantium, Concord.new(:klass, :test_method)

        # Identification string
        #
        # @return [String]
        def identification
          IDENTIFICATION_FORMAT % [klass, test_method]
        end
        memoize :identification

        # Run test case
        #
        # @param [Object] reporter
        #
        # @return [Boolean]
        def call(reporter)
          ::Minitest::Runnable.run_one_method(klass, test_method, reporter)
          reporter.passed?
        end

        # Cover expression syntaxes
        #
        # @return [String, nil]
        def expression_syntax
          klass.resolve_cover_expression
        end

      end # TestCase

      private_constant(*constants(false))

      # Setup integration
      #
      # @return [self]
      def setup
        Pathname.glob(TEST_FILE_PATTERN)
          .map(&:to_s)
          .each(&method(:require))

        self
      end

      # Call test integration
      #
      # @param [Array<Tests>] tests
      #
      # @return [Result::Test]
      #
      # rubocop:disable Metrics/MethodLength
      #
      # ignore :reek:TooManyStatements
      def call(tests)
        test_cases = tests.map(&all_tests_index.method(:fetch))
        output     = StringIO.new
        start      = Timer.now

        reporter = ::Minitest::SummaryReporter.new(output)

        reporter.start

        test_cases.each do |test|
          break unless test.call(reporter)
        end

        output.rewind

        Result::Test.new(
          passed:  reporter.passed?,
          tests:   tests,
          output:  output.read,
          runtime: Timer.now - start
        )
      end

      # All tests exposed by this integration
      #
      # @return [Array<Test>]
      def all_tests
        all_tests_index.keys
      end
      memoize :all_tests

    private

      def all_tests_index
        all_test_cases.each_with_object({}) do |test_case, index|
          index[construct_test(test_case)] = test_case
        end
      end
      memoize :all_tests_index

      def construct_test(test_case)
        Test.new(
          id:          test_case.identification,
          expressions: [config.expression_parser.apply(test_case.expression_syntax).from_right]
        )
      end

      def all_test_cases
        ::Minitest::Runnable
          .runnables
          .select(&method(:allow_runnable?))
          .flat_map(&method(:test_case))
      end

      def allow_runnable?(klass)
        !klass.equal?(::Minitest::Runnable) && klass.resolve_cover_expression
      end

      def test_case(runnable)
        runnable.runnable_methods.map { |method| TestCase.new(runnable, method) }
      end
    end # Minitest
  end # Integration
end # Mutant

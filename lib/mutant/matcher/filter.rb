# frozen_string_literal: true

module Mutant
  class Matcher
    # Matcher filter
    class Filter < self
      include Anima.new(:matcher, :predicate)

      # Enumerate matches
      #
      # @param [Env] env
      #
      # @return [Enumerable<Subject>]
      def call(env)
        matcher
          .call(env)
          .select(&predicate.method(:call))
      end

    end # Filter
  end # Matcher
end # Mutant

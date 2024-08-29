# frozen_string_literal: true

require "benchmark"

class << Benchmark
  def ms(&block) # :nodoc
    # NOTE: Please also remove the Active Support `benchmark` dependency when removing this
    ActiveSupport.deprecator.warn <<~TEXT
      `Benchmark.ms` is deprecated and will be removed in Rails 8.1.
      Use `1000 * Benchmark.realtime(&block)` instead.
    TEXT
    1000 * realtime(&block)
  end
end

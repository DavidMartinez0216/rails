module ActiveRecord
  module Explain
    extend ActiveSupport::Concern

    module ClassMethods
      # If auto explain is enabled, this method triggers EXPLAIN logging for the
      # queries triggered by the block if it takes more than the threshold as a
      # whole. That is, the threshold is not checked against each individual
      # query, but against the duration of the entire block. This approach is
      # convenient for relations.
      #
      # The available_queries_for_explain thread variable collects the queries
      # to be explained. If the value is nil, it means queries are not being
      # currently collected. A false value indicates collecting is turned
      # off. Otherwise it is an array of queries.
      def logging_query_plan # :nodoc:
        threshold = auto_explain_threshold_in_seconds
        current   = Thread.current
        if threshold && current[:available_queries_for_explain].nil?
          begin
            value = current[:available_queries_for_explain] = []
            start = Time.now
            result = yield
            logger.warn(exec_explain(value)) if Time.now - start > threshold
            result
          ensure
            current[:available_queries_for_explain] = nil
          end
        else
          yield
        end
      end

      # Receives a payload and check if the SQL query should be collected.
      def collect_sql_for_explain(payload)
        if value = Thread.current[:available_queries_for_explain]
          unless ignore_explain_notification?(payload)
            value << [payload[:sql], payload[:binds]]
          end
        end
      end

      # SCHEMA queries cannot be EXPLAINed, also we do not want to run EXPLAIN on
      # our own EXPLAINs now matter how loopingly beautiful that would be.
      SKIP_EXPLAIN_FOR = %w(SCHEMA EXPLAIN)
      def ignore_explain_notification?(payload) # :nodoc:
        payload[:exception] || SKIP_EXPLAIN_FOR.include?(payload[:name])
      end

      # Makes the adapter execute EXPLAIN for the tuples of queries and bindings.
      # Returns a formatted string ready to be logged.
      def exec_explain(value) # :nodoc:
        value && value.map do |sql, bind|
          [].tap do |msg|
            msg << "EXPLAIN for: #{sql}"
            unless bind.empty?
              bind_msg = bind.map {|col, val| [col.name, val]}.inspect
              msg.last << " #{bind_msg}"
            end
            msg << connection.explain(sql, bind)
          end.join("\n")
        end.join("\n")
      end

      # Silences automatic EXPLAIN logging for the duration of the block.
      #
      # This has high priority, no EXPLAINs will be run even if downwards
      # the threshold is set to 0.
      #
      # As the name of the method suggests this only applies to automatic
      # EXPLAINs, manual calls to +ActiveRecord::Relation#explain+ run.
      def silence_auto_explain
        current = Thread.current
        original, current[:available_queries_for_explain] = current[:available_queries_for_explain], false
        yield
      ensure
        current[:available_queries_for_explain] = original
      end
    end

    # A convenience instance method that delegates to the class method of the
    # same name.
    def silence_auto_explain(&block)
      self.class.silence_auto_explain(&block)
    end
  end
end

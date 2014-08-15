module ActiveRecord
  module Type
    class Float < Numeric # :nodoc:

      def type
        :float
      end

      alias type_cast_for_database type_cast

      private

      def cast_value(value)
        value.to_f
      end
    end
  end
end

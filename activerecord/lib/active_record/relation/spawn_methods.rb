module ActiveRecord
  module SpawnMethods
    def spawn(arel_table = self.table)
      relation = Relation.new(@klass, arel_table)

      (Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS).each do |query_method|
        relation.send(:"#{query_method}_values=", send(:"#{query_method}_values"))
      end

      Relation::SINGLE_VALUE_METHODS.each do |query_method|
        relation.send(:"#{query_method}_value=", send(:"#{query_method}_value"))
      end

      relation
    end

    def merge(r)
      raise ArgumentError, "Cannot merge a #{r.klass.name} relation with #{@klass.name} relation" if r.klass != @klass

      merged_relation = spawn.eager_load(r.eager_load_values).preload(r.preload_values).includes(r.includes_values)

      merged_relation.readonly_value = r.readonly_value unless merged_relation.readonly_value
      merged_relation.limit_value = r.limit_value unless merged_relation.limit_value
      merged_relation.lock_value = r.lock_value unless merged_relation.lock_value

      merged_relation = merged_relation.
        joins(r.joins_values).
        group(r.group_values).
        offset(r.offset_value).
        select(r.select_values).
        from(r.from_value).
        having(r.having_values)

      relation_order = r.order_values
      merged_order = relation_order.present? ? relation_order : order_values
      merged_relation.order_values = merged_order

      merged_relation.create_with_value = @create_with_value

      if @create_with_value && r.create_with_value
        merged_relation.create_with_value = @create_with_value.merge(r.create_with_value)
      else
        merged_relation.create_with_value = r.create_with_value || @create_with_value
      end

      merged_wheres = @where_values

      r.where_values.each do |w|
        if w.is_a?(Arel::Predicates::Equality)
          merged_wheres = merged_wheres.reject {|p| p.is_a?(Arel::Predicates::Equality) && p.operand1.name == w.operand1.name }
        end

        merged_wheres << w
      end

      merged_relation.where_values = merged_wheres

      merged_relation
    end

    alias :& :merge

    def except(*skips)
      result = Relation.new(@klass, table)

      (Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values")) unless skips.include?(method)
      end

      Relation::SINGLE_VALUE_METHODS.each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value")) unless skips.include?(method)
      end

      result
    end

  end
end

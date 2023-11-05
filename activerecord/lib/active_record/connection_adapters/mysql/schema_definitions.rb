# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module ColumnMethods
        extend ActiveSupport::Concern

        # Defines the primary key field.
        # Use of the native MariaDB UUID type is supported, and can be used
        # by defining your tables as such:
        #
        #   create_table :stuffs, id: :uuid do |t|
        #     t.string :content
        #     t.timestamps
        #   end
        #
        # By default, this will use the <tt>uuid()</tt> function, which generates
        # UUIDv1 values. You may also explicitly pass a different UUID generation function:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: "sys_guid()"
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # To use a UUID primary key without any defaults, set the
        # +:default+ option to +nil+:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: nil
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # Note that setting the UUID primary key default value to +nil+ will
        # require you to assure that you always provide a UUID value before saving
        # a record (as primary keys cannot be +nil+). This might be done via the
        # +SecureRandom.uuid+ method and a +before_save+ callback, for instance.
        def primary_key(name, type = :primary_key, **options)
          if type == :uuid
            options[:default] = options.fetch(:default, "uuid()")
          end

          super
        end

        ##
        # :method: blob
        # :call-seq: blob(*names, **options)

        ##
        # :method: tinyblob
        # :call-seq: tinyblob(*names, **options)

        ##
        # :method: mediumblob
        # :call-seq: mediumblob(*names, **options)

        ##
        # :method: longblob
        # :call-seq: longblob(*names, **options)

        ##
        # :method: tinytext
        # :call-seq: tinytext(*names, **options)

        ##
        # :method: mediumtext
        # :call-seq: mediumtext(*names, **options)

        ##
        # :method: longtext
        # :call-seq: longtext(*names, **options)

        ##
        # :method: unsigned_integer
        # :call-seq: unsigned_integer(*names, **options)

        ##
        # :method: unsigned_bigint
        # :call-seq: unsigned_bigint(*names, **options)

        ##
        # :method: unsigned_float
        # :call-seq: unsigned_float(*names, **options)

        ##
        # :method: unsigned_decimal
        # :call-seq: unsigned_decimal(*names, **options)

        ##
        # :method: uuid
        # :call-seq: uuid(*names, **options)

        included do
          define_column_methods :blob, :tinyblob, :mediumblob, :longblob,
            :tinytext, :mediumtext, :longtext, :unsigned_integer, :unsigned_bigint,
            :unsigned_float, :unsigned_decimal, :uuid
        end
      end

      # = Active Record MySQL Adapter \Table Definition
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        attr_reader :charset, :collation

        def initialize(conn, name, charset: nil, collation: nil, **)
          super
          @charset = charset
          @collation = collation
        end

        def new_column_definition(name, type, **options) # :nodoc:
          case type
          when :virtual
            type = options[:type]
          when :primary_key
            type = :integer
            options[:limit] ||= 8
            options[:primary_key] = true
          when /\Aunsigned_(?<type>.+)\z/
            type = $~[:type].to_sym
            options[:unsigned] = true
          end

          super
        end

        private
          def valid_column_definition_options
            super + [:auto_increment, :charset, :as, :size, :unsigned, :first, :after, :type, :stored]
          end

          def aliased_types(name, fallback)
            fallback
          end

          def integer_like_primary_key_type(type, options)
            unless options[:auto_increment] == false
              options[:auto_increment] = true
            end

            type
          end
      end

      # = Active Record MySQL Adapter \Table
      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end

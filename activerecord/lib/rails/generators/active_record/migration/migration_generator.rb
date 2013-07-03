require 'rails/generators/active_record'

module ActiveRecord
  module Generators # :nodoc:
    class MigrationGenerator < Base # :nodoc:
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"

      def create_migration_file
        set_local_assigns!
        validate_file_name!
        destination = "db/migrate/#{file_name}.rb"
        migration_template @migration_template, destination
        open_file_in_editor(destination) if options["editor"].present?
      end

      protected
      attr_reader :migration_action, :join_tables

      # sets the default migration template that is being used for the generation of the migration
      # depending on the arguments which would be sent out in the command line, the migration template 
      # and the table name instance variables are setup.

      def set_local_assigns!
        @migration_template = "migration.rb"
        case file_name
        when /^(add|remove)_.*_(?:to|from)_(.*)/
          @migration_action = $1
          @table_name       = $2.pluralize
        when /join_table/
          if attributes.length == 2
            @migration_action = 'join'
            @join_tables      = attributes.map(&:plural_name)

            set_index_names
          end
        when /^create_(.+)/
          @table_name = $1.pluralize
          @migration_template = "create_table_migration.rb"
        end
      end

      def set_index_names
        attributes.each_with_index do |attr, i|
          attr.index_name = [attr, attributes[i - 1]].map{ |a| index_name_for(a) }
        end
      end

      def index_name_for(attribute)
        if attribute.foreign_key?
          attribute.name
        else
          attribute.name.singularize.foreign_key
        end.to_sym
      end

      private
        def attributes_with_index
          attributes.select { |a| !a.reference? && a.has_index? }
        end
        
        def validate_file_name!
          unless file_name =~ /^[_a-z0-9]+$/
            raise IllegalMigrationNameError.new(file_name)
          end
        end
    end
  end
end

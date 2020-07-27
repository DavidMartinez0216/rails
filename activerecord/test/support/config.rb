# frozen_string_literal: true

require "fileutils"
require "active_support/configuration_file"

module ARTest
  class << self
    def config
      @config ||= read_config
    end

    private
      def config_file
        ENV.fetch("ARCONFIG", File.join(TEST_ROOT, "config.yml"))
      end

      def read_config
        install_example_config unless File.exist?(config_file)

        expand_config ActiveSupport::ConfigurationFile.parse(config_file)
      end

      def install_example_config
        FileUtils.cp(File.join(TEST_ROOT, "config.example.yml"), config_file)
      end

      def expand_config(config)
        config["connections"].each do |adapter, connection|
          dbs = [["arunit", "activerecord_unittest"], ["arunit2", "activerecord_unittest2"],
                 ["arunit_without_prepared_statements", "activerecord_unittest"]]
          dbs.each do |name, dbname|
            unless connection[name].is_a?(Hash)
              connection[name] = { "database" => connection[name] }
            end

            connection[name]["database"] ||= dbname
            connection[name]["adapter"]  ||= adapter
          end
        end

        config
      end
  end
end

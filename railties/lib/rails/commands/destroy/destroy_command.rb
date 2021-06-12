# frozen_string_literal: true

require "rails/generators"
require_relative "destroy_assistance"

module Rails
  module Command
    class DestroyCommand < Base # :nodoc:
      no_commands do
        def help
          require_application_and_environment!
          load_generators

          Rails::Generators.help self.class.command_name
        end
      end

      def perform(*)
        generator = args.shift
        return help unless generator

        require_application_and_environment!
        load_generators

        Rails::Generators.invoke generator, args, behavior: :revoke, destination_root: Rails::Command.root
        return DestroyAssistance.delete_css_file_generate_with_scaffold if generator == "scaffold"
      end
    end
  end
end

# frozen_string_literal: true

require "rails/generators"
require "fileutils"

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

      def delete_css_file_generate_with_scaffold
        path = Rails.root.join('app', 'assets', 'stylesheets', 'scaffolds.scss')
        FileUtils.remove_file(path,force=true)
        puts " "*6+"\e[31mremove\e[0m"+" "*4  + path.to_s.split("/").reverse.slice(0,4).reverse.join("/")
        puts path
      end

      def perform(*)
        generator = args.shift
        return help unless generator

        require_application_and_environment!
        load_generators
        Rails::Generators.invoke generator, args, behavior: :revoke, destination_root: Rails::Command.root
        return delete_css_file_generate_with_scaffold if generator == "scaffold"
      end
    end
  end
end

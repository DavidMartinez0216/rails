# frozen_string_literal: true

module ActionText
  # Generic base class for all Action Text exceptions.
  class Error < StandardError; end

  if defined?(Rails)
    require "active_support/actionable_error"
    require "rails/command"

    # Raised when we detect that Action Text has not been initialized.
    class InstallError < Error
      include ActiveSupport::ActionableError

      def initialize(message = nil)
        super(message || <<~MESSAGE)
          Action Text does not appear to be installed. Do you want to
          install it now?
        MESSAGE
      end

      trigger on: ActiveRecord::StatementInvalid, if: -> error do
        error.message.match?(RichText.table_name)
      end

      action "Install now" do
        Rails::Command.invoke("action_text:install")
        Rails::Command.invoke("db:migrate")
      end
    end
  end
end

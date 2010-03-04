require "rails"
require "action_controller"
require "action_view/railtie"
require "active_support/core_ext/class/subclasses"
require "active_support/deprecation/proxy_wrappers"

module ActionController
  class Railtie < Rails::Railtie
    railtie_name :action_controller

    require "action_controller/railties/log_subscriber"
    require "action_controller/railties/url_helpers"

    log_subscriber ActionController::Railties::LogSubscriber.new

    config.action_controller.session_store = :cookie_store
    config.action_controller.session_options = {}

    initializer "action_controller.logger" do
      ActionController::Base.logger ||= Rails.logger
    end

    # assets_dir = defined?(Rails.public_path) ? Rails.public_path : "public"
    # ActionView::DEFAULT_CONFIG = {
    #   :assets_dir => assets_dir,
    #   :javascripts_dir => "#{assets_dir}/javascripts",
    #   :stylesheets_dir => "#{assets_dir}/stylesheets",
    # }


    initializer "action_controller.set_configs" do |app|
      paths = app.config.paths
      ac = app.config.action_controller
      ac.assets_dir = paths.public
      ac.javascripts_dir = paths.public.javascripts
      ac.stylesheets_dir = paths.public.stylesheets

      app.config.action_controller.each do |k,v|
        ActionController::Base.send "#{k}=", v
      end
    end

    initializer "action_controller.initialize_framework_caches" do
      ActionController::Base.cache_store ||= RAILS_CACHE
    end

    initializer "action_controller.set_helpers_path" do |app|
      ActionController::Base.helpers_path = app.config.paths.app.helpers.to_a
    end

    initializer "action_controller.url_helpers" do |app|
      ActionController::Base.extend ::ActionController::Railtie::UrlHelpers.with(app.routes)

      message = "ActionController::Routing::Routes is deprecated. " \
                "Instead, use Rails.application.routes"

      proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(app.routes, message)
      ActionController::Routing::Routes = proxy
    end
  end
end
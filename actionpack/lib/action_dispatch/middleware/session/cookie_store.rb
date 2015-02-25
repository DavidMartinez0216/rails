require 'active_support/core_ext/hash/keys'
require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/cookie'

module ActionDispatch
  module Session
    # This cookie-based session store is the Rails default. It is
    # dramatically faster than the alternatives.
    #
    # Sessions typically contain at most a user_id and flash message; both fit
    # within the 4K cookie size limit. A CookieOverflow exception is raised if
    # you attempt to store more than 4K of data.
    #
    # The cookie jar used for storage is automatically configured to be the
    # best possible option given your application's configuration.
    #
    # If you only have secret_token set, your cookies will be signed, but
    # not encrypted. This means a user cannot alter their +user_id+ without
    # knowing your app's secret key, but can easily read their +user_id+. This
    # was the default for Rails 3 apps.
    #
    # If you have secret_key_base set, your cookies will be encrypted. This
    # goes a step further than signed cookies in that encrypted cookies cannot
    # be altered or read by users. This is the default starting in Rails 4.
    #
    # If you have both secret_token and secret_key base set, your cookies will
    # be encrypted, and signed cookies generated by Rails 3 will be
    # transparently read and encrypted to provide a smooth upgrade path.
    #
    # Configure your session store in config/initializers/session_store.rb:
    #
    #   Rails.application.config.session_store :cookie_store, key: '_your_app_session'
    #
    # Configure your secret key in config/secrets.yml:
    #
    #   development:
    #     secret_key_base: 'secret key'
    #
    # To generate a secret key for an existing application, run `rake secret`.
    #
    # If you are upgrading an existing Rails 3 app, you should leave your
    # existing secret_token in place and simply add the new secret_key_base.
    # Note that you should wait to set secret_key_base until you have 100% of
    # your userbase on Rails 4 and are reasonably sure you will not need to
    # rollback to Rails 3. This is because cookies signed based on the new
    # secret_key_base in Rails 4 are not backwards compatible with Rails 3.
    # You are free to leave your existing secret_token in place, not set the
    # new secret_key_base, and ignore the deprecation warnings until you are
    # reasonably sure that your upgrade is otherwise complete. Additionally,
    # you should take care to make sure you are not relying on the ability to
    # decode signed cookies generated by your app in external applications or
    # JavaScript before upgrading.
    #
    # Note that changing the secret key will invalidate all existing sessions!
    class CookieStore < Rack::Session::Abstract::ID
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      def initialize(app, options={})
        super(app, options.merge!(:cookie_only => true))
      end

      def destroy_session(env, session_id, options)
        new_sid = generate_sid unless options[:drop]
        # Reset hash and Assign the new session id
        env["action_dispatch.request.unsigned_session_cookie"] = new_sid ? { "session_id" => new_sid } : {}
        new_sid
      end

      def load_session(env)
        stale_session_check! do
          data = unpacked_cookie_data(env)
          data = persistent_session_id!(data)
          [data["session_id"], data]
        end
      end

      private

      def extract_session_id(env)
        stale_session_check! do
          unpacked_cookie_data(env)["session_id"]
        end
      end

      def unpacked_cookie_data(env)
        env["action_dispatch.request.unsigned_session_cookie"] ||= begin
          stale_session_check! do
            if data = get_cookie(env)
              data.stringify_keys!
            end
            data || {}
          end
        end
      end

      def persistent_session_id!(data, sid=nil)
        data ||= {}
        data["session_id"] ||= sid || generate_sid
        data
      end

      def set_session(env, sid, session_data, options)
        session_data["session_id"] = sid
        session_data
      end

      def set_cookie(env, session_id, cookie)
        cookie_jar(env)[@key] = cookie
      end

      def get_cookie(env)
        cookie_jar(env)[@key]
      end

      def cookie_jar(env)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar.signed_or_encrypted
      end

      def valid_cookie?(env)
        cookie = get_cookie(env)
        cookie_jar(env).validate_cookie_with_all_keys(cookie)
      end
    end
  end
end

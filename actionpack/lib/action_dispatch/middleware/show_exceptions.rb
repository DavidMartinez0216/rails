# frozen_string_literal: true

require_relative "../http/request"
require_relative "exception_wrapper"

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and calls an exceptions app that will wrap it in a format for the end user.
  #
  # The exceptions app should be passed as parameter on initialization
  # of ShowExceptions. Every time there is an exception, ShowExceptions will
  # store the exception in env["action_dispatch.exception"], rewrite the
  # PATH_INFO to the exception status code and call the Rack app.
  #
  # If the application returns a "X-Cascade" pass response, this middleware
  # will send an empty response as result with the correct status code.
  # If any exception happens inside the exceptions app, this middleware
  # catches the exceptions and returns a FAILSAFE_RESPONSE.
  class ShowExceptions
    FAILSAFE_RESPONSE = [500, { "Content-Type" => "text/plain" },
      ["500 Internal Server Error\n" \
       "If you are the administrator of this website, then please read this web " \
       "application's log file and/or the web server's log file to find out what " \
       "went wrong."]]

    def initialize(app, exceptions_app)
      @app = app
      @exceptions_app = exceptions_app
    end

    def call(env)
      request = ActionDispatch::Request.new env
      _, headers, body = response = @app.call(env)

      if headers["X-Cascade"] == "pass"
        body.close if body.respond_to?(:close)
        raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
      end

      response
    rescue Exception => exception
      if request.show_exceptions?
        render_exception(request, exception)
      else
        raise exception
      end
    end

    private

      def render_exception(request, exception)
        backtrace_cleaner = request.get_header "action_dispatch.backtrace_cleaner"
        wrapper = ExceptionWrapper.new(backtrace_cleaner, exception)
        status  = wrapper.status_code
        request.set_header "action_dispatch.unwrapped_exception", exception
        request.set_header "action_dispatch.exception", wrapper.exception
        request.set_header "action_dispatch.original_path", request.path_info
        request.path_info = "/#{status}"
        response = @exceptions_app.call(request.env)
        response[1]["X-Cascade"] == "pass" ? pass_response(status) : response
      rescue Exception => failsafe_error
        $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
        FAILSAFE_RESPONSE
      end

      def pass_response(status)
        [status, { "Content-Type" => "text/html; charset=#{Response.default_charset}", "Content-Length" => "0" }, []]
      end
  end
end

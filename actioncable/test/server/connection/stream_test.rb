# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_server"

class ActionCable::Server::Connection::StreamTest < ActionCable::TestCase
  class Connection < ActionCable::Server::Connection
    class Delegate
      def initialize(conn)
        @conn = conn
      end

      def handle_open = @conn.connect

      def handle_close = @conn.disconnect
    end

    attr_reader :connected, :websocket, :errors

    def initialize(*)
      super
      @errors = []
      @app_conn = Delegate.new(self)
    end

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
    end

    def on_error(message)
      @errors << message
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  [ EOFError, Errno::ECONNRESET ].each do |closed_exception|
    test "closes socket on #{closed_exception}" do
      run_in_eventmachine do
        rack_hijack_io = File.open(File::NULL, "w")
        connection = open_connection(rack_hijack_io)

        # Internal hax = :(
        client = connection.websocket.send(:websocket)
        rack_hijack_io.stub(:write_nonblock, proc { raise(closed_exception, "foo") }) do
          assert_called(client, :client_gone) do
            client.write("boo")
          end
        end
        assert_equal [], connection.errors
      end
    end
  end

  private
    def open_connection(io)
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
      env["rack.hijack"] = -> { env["rack.hijack_io"] = io }

      Connection.new(@server, env).tap do |connection|
        connection.process
        connection.send :handle_open
        assert connection.connected
      end
    end
end

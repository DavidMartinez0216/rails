require 'action_dispatch/journey'
require 'forwardable'
require 'thread_safe'
require 'active_support/concern'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/array/extract_options'
require 'action_controller/metal/exceptions'
require 'action_dispatch/http/request'
require 'action_dispatch/routing/endpoint'

module ActionDispatch
  module Routing
    class RouteSet #:nodoc:
      # Since the router holds references to many parts of the system
      # like engines, controllers and the application itself, inspecting
      # the route set can actually be really slow, therefore we default
      # alias inspect to to_s.
      alias inspect to_s

      class Dispatcher < Routing::Endpoint #:nodoc:
        def initialize(defaults)
          @defaults = defaults
          @controller_class_names = ThreadSafe::Cache.new
        end

        def dispatcher?; true; end

        def serve(req)
          req.check_path_parameters!
          params = req.path_parameters

          prepare_params!(params)

          # Just raise undefined constant errors if a controller was specified as default.
          unless controller = controller(params, @defaults.key?(:controller))
            return [404, {'X-Cascade' => 'pass'}, []]
          end

          dispatch(controller, params[:action], req.env)
        end

        def prepare_params!(params)
          normalize_controller!(params)
          merge_default_action!(params)
        end

        # If this is a default_controller (i.e. a controller specified by the user)
        # we should raise an error in case it's not found, because it usually means
        # a user error. However, if the controller was retrieved through a dynamic
        # segment, as in :controller(/:action), we should simply return nil and
        # delegate the control back to Rack cascade. Besides, if this is not a default
        # controller, it means we should respect the @scope[:module] parameter.
        def controller(params, default_controller=true)
          if params && params.key?(:controller)
            controller_param = params[:controller]
            controller_reference(controller_param)
          end
        rescue NameError => e
          raise ActionController::RoutingError, e.message, e.backtrace if default_controller
        end

      private

        def controller_reference(controller_param)
          const_name = @controller_class_names[controller_param] ||= "#{controller_param.camelize}Controller"
          ActiveSupport::Dependencies.constantize(const_name)
        end

        def dispatch(controller, action, env)
          controller.action(action).call(env)
        end

        def normalize_controller!(params)
          params[:controller] = params[:controller].underscore if params.key?(:controller)
        end

        def merge_default_action!(params)
          params[:action] ||= 'index'
        end
      end

      # A NamedRouteCollection instance is a collection of named routes, and also
      # maintains an anonymous module that can be used to install helpers for the
      # named routes.
      class NamedRouteCollection #:nodoc:
        include Enumerable
        attr_reader :routes, :helpers, :module

        def initialize
          @routes  = {}
          @helpers = []
          @module  = Module.new
        end

        def helper_names
          @helpers.map(&:to_s)
        end

        def clear!
          @helpers.each do |helper|
            @module.remove_possible_method helper
          end

          @routes.clear
          @helpers.clear
        end

        def add(name, route)
          routes[name.to_sym] = route
          define_named_route_methods(name, route)
        end

        def get(name)
          routes[name.to_sym]
        end

        alias []=   add
        alias []    get
        alias clear clear!

        def each
          routes.each { |name, route| yield name, route }
          self
        end

        def names
          routes.keys
        end

        def length
          routes.length
        end

        class UrlHelper # :nodoc:
          def self.create(route, options)
            if optimize_helper?(route)
              OptimizedUrlHelper.new(route, options)
            else
              new route, options
            end
          end

          def self.optimize_helper?(route)
            !route.glob? && route.path.requirements.empty?
          end

          class OptimizedUrlHelper < UrlHelper # :nodoc:
            attr_reader :arg_size

            def initialize(route, options)
              super
              @required_parts = @route.required_parts
              @arg_size       = @required_parts.size
            end

            def call(t, args)
              if args.size == arg_size && !args.last.is_a?(Hash) && optimize_routes_generation?(t)
                options = t.url_options.merge @options
                options[:path] = optimized_helper(args)
                ActionDispatch::Http::URL.url_for(options)
              else
                super
              end
            end

            private

            def optimized_helper(args)
              params = parameterize_args(args)
              missing_keys = missing_keys(params)

              unless missing_keys.empty?
                raise_generation_error(params, missing_keys)
              end

              @route.format params
            end

            def optimize_routes_generation?(t)
              t.send(:optimize_routes_generation?)
            end

            def parameterize_args(args)
              params = {}
              @required_parts.zip(args.map(&:to_param)) { |k,v| params[k] = v }
              params
            end

            def missing_keys(args)
              args.select{ |part, arg| arg.nil? || arg.empty? }.keys
            end

            def raise_generation_error(args, missing_keys)
              constraints = Hash[@route.requirements.merge(args).sort]
              message = "No route matches #{constraints.inspect}"
              message << " missing required keys: #{missing_keys.sort.inspect}"

              raise ActionController::UrlGenerationError, message
            end
          end

          def initialize(route, options)
            @options      = options
            @segment_keys = route.segment_keys.uniq
            @route        = route
          end

          def call(t, args)
            controller_options = t.url_options
            options = controller_options.merge @options
            hash = handle_positional_args(controller_options, args, options, @segment_keys)
            t._routes.url_for(hash)
          end

          def handle_positional_args(controller_options, args, result, path_params)
            inner_options = args.extract_options!

            if args.size > 0
              if args.size < path_params.size - 1 # take format into account
                path_params -= controller_options.keys
                path_params -= result.keys
              end
              path_params.each { |param|
                result[param] = inner_options[param] || args.shift
              }
            end

            result.merge!(inner_options)
          end
        end

        private
        # Create a url helper allowing ordered parameters to be associated
        # with corresponding dynamic segments, so you can do:
        #
        #   foo_url(bar, baz, bang)
        #
        # Instead of:
        #
        #   foo_url(bar: bar, baz: baz, bang: bang)
        #
        # Also allow options hash, so you can do:
        #
        #   foo_url(bar, baz, bang, sort_by: 'baz')
        #
        def define_url_helper(route, name, options)
          helper = UrlHelper.create(route, options.dup)

          @module.remove_possible_method name
          @module.module_eval do
            define_method(name) do |*args|
              helper.call self, args
            end
          end

          helpers << name
        end

        def define_named_route_methods(name, route)
          define_url_helper route, :"#{name}_path",
            route.defaults.merge(:use_route => name, :only_path => true)
          define_url_helper route, :"#{name}_url",
            route.defaults.merge(:use_route => name, :only_path => false)
        end
      end

      attr_accessor :formatter, :set, :named_routes, :default_scope, :router
      attr_accessor :disable_clear_and_finalize, :resources_path_names
      attr_accessor :default_url_options, :request_class

      alias :routes :set

      def self.default_resources_path_names
        { :new => 'new', :edit => 'edit', :edit_many => 'edit' }
      end

      def initialize(request_class = ActionDispatch::Request)
        self.named_routes = NamedRouteCollection.new
        self.resources_path_names = self.class.default_resources_path_names.dup
        self.default_url_options = {}
        self.request_class = request_class

        @append                     = []
        @prepend                    = []
        @disable_clear_and_finalize = false
        @finalized                  = false

        @set    = Journey::Routes.new
        @router = Journey::Router.new @set
        @formatter = Journey::Formatter.new @set
      end

      def draw(&block)
        clear! unless @disable_clear_and_finalize
        eval_block(block)
        finalize! unless @disable_clear_and_finalize
        nil
      end

      def append(&block)
        @append << block
      end

      def prepend(&block)
        @prepend << block
      end

      def eval_block(block)
        if block.arity == 1
          raise "You are using the old router DSL which has been removed in Rails 3.1. " <<
            "Please check how to update your routes file at: http://www.engineyard.com/blog/2010/the-lowdown-on-routes-in-rails-3/"
        end
        mapper = Mapper.new(self)
        if default_scope
          mapper.with_default_scope(default_scope, &block)
        else
          mapper.instance_exec(&block)
        end
      end

      def finalize!
        return if @finalized
        @append.each { |blk| eval_block(blk) }
        @finalized = true
      end

      def clear!
        @finalized = false
        named_routes.clear
        set.clear
        formatter.clear
        @prepend.each { |blk| eval_block(blk) }
      end

      module MountedHelpers #:nodoc:
        extend ActiveSupport::Concern
        include UrlFor
      end

      # Contains all the mounted helpers across different
      # engines and the `main_app` helper for the application.
      # You can include this in your classes if you want to
      # access routes for other engines.
      def mounted_helpers
        MountedHelpers
      end

      def define_mounted_helper(name)
        return if MountedHelpers.method_defined?(name)

        routes = self
        MountedHelpers.class_eval do
          define_method "_#{name}" do
            RoutesProxy.new(routes, _routes_context)
          end
        end

        MountedHelpers.class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
          def #{name}
            @_#{name} ||= _#{name}
          end
        RUBY
      end

      def url_helpers
        @url_helpers ||= begin
          routes = self

          Module.new do
            extend ActiveSupport::Concern
            include UrlFor

            # Define url_for in the singleton level so one can do:
            # Rails.application.routes.url_helpers.url_for(args)
            @_routes = routes
            class << self
              delegate :url_for, :optimize_routes_generation?, :to => '@_routes'
              attr_reader :_routes
              def url_options; {}; end
            end

            # Make named_routes available in the module singleton
            # as well, so one can do:
            # Rails.application.routes.url_helpers.posts_path
            extend routes.named_routes.module

            # Any class that includes this module will get all
            # named routes...
            include routes.named_routes.module

            # plus a singleton class method called _routes ...
            included do
              singleton_class.send(:redefine_method, :_routes) { routes }
            end

            # And an instance method _routes. Note that
            # UrlFor (included in this module) add extra
            # conveniences for working with @_routes.
            define_method(:_routes) { @_routes || routes }
          end
        end
      end

      def empty?
        routes.empty?
      end

      def add_route(app, conditions = {}, requirements = {}, defaults = {}, name = nil, anchor = true)
        raise ArgumentError, "Invalid route name: '#{name}'" unless name.blank? || name.to_s.match(/^[_a-z]\w*$/i)

        if name && named_routes[name]
          raise ArgumentError, "Invalid route name, already in use: '#{name}' \n" \
            "You may have defined two routes with the same name using the `:as` option, or " \
            "you may be overriding a route already defined by a resource with the same naming. " \
            "For the latter, you can restrict the routes created with `resources` as explained here: \n" \
            "http://guides.rubyonrails.org/routing.html#restricting-the-routes-created"
        end

        path = conditions.delete :path_info
        ast  = conditions.delete :parsed_path_info
        path = build_path(path, ast, requirements, anchor)
        conditions = build_conditions(conditions, path.names.map { |x| x.to_sym })

        route = @set.add_route(app, path, conditions, defaults, name)
        named_routes[name] = route if name
        route
      end

      def build_path(path, ast, requirements, anchor)
        strexp = Journey::Router::Strexp.new(
            ast,
            path,
            requirements,
            SEPARATORS,
            anchor)

        pattern = Journey::Path::Pattern.new(strexp)

        builder = Journey::GTG::Builder.new pattern.spec

        # Get all the symbol nodes followed by literals that are not the
        # dummy node.
        symbols = pattern.spec.grep(Journey::Nodes::Symbol).find_all { |n|
          builder.followpos(n).first.literal?
        }

        # Get all the symbol nodes preceded by literals.
        symbols.concat pattern.spec.find_all(&:literal?).map { |n|
          builder.followpos(n).first
        }.find_all(&:symbol?)

        symbols.each { |x|
          x.regexp = /(?:#{Regexp.union(x.regexp, '-')})+/
        }

        pattern
      end
      private :build_path

      def build_conditions(current_conditions, path_values)
        conditions = current_conditions.dup

        # Rack-Mount requires that :request_method be a regular expression.
        # :request_method represents the HTTP verb that matches this route.
        #
        # Here we munge values before they get sent on to rack-mount.
        verbs = conditions[:request_method] || []
        unless verbs.empty?
          conditions[:request_method] = %r[^#{verbs.join('|')}$]
        end

        conditions.keep_if do |k, _|
          k == :action || k == :controller || k == :required_defaults ||
            @request_class.public_method_defined?(k) || path_values.include?(k)
        end
      end
      private :build_conditions

      class Generator #:nodoc:
        PARAMETERIZE = lambda do |name, value|
          if name == :controller
            value
          elsif value.is_a?(Array)
            value.map { |v| v.to_param }.join('/')
          elsif param = value.to_param
            param
          end
        end

        attr_reader :options, :recall, :set, :named_route

        def initialize(options, recall, set)
          @named_route = options.delete(:use_route)
          @options     = options.dup
          @recall      = recall.dup
          @set         = set

          normalize_recall!
          normalize_options!
          normalize_controller_action_id!
          use_relative_controller!
          normalize_controller!
          normalize_action!
        end

        def controller
          @options[:controller]
        end

        def current_controller
          @recall[:controller]
        end

        def use_recall_for(key)
          if @recall[key] && (!@options.key?(key) || @options[key] == @recall[key])
            if !named_route_exists? || segment_keys.include?(key)
              @options[key] = @recall.delete(key)
            end
          end
        end

        # Set 'index' as default action for recall
        def normalize_recall!
          @recall[:action] ||= 'index'
        end

        def normalize_options!
          # If an explicit :controller was given, always make :action explicit
          # too, so that action expiry works as expected for things like
          #
          #   generate({controller: 'content'}, {controller: 'content', action: 'show'})
          #
          # (the above is from the unit tests). In the above case, because the
          # controller was explicitly given, but no action, the action is implied to
          # be "index", not the recalled action of "show".

          if options[:controller]
            options[:action]     ||= 'index'
            options[:controller]   = options[:controller].to_s
          end

          if options.key?(:action)
            options[:action] = (options[:action] || 'index').to_s
          end
        end

        # This pulls :controller, :action, and :id out of the recall.
        # The recall key is only used if there is no key in the options
        # or if the key in the options is identical. If any of
        # :controller, :action or :id is not found, don't pull any
        # more keys from the recall.
        def normalize_controller_action_id!
          use_recall_for(:controller) or return
          use_recall_for(:action) or return
          use_recall_for(:id)
        end

        # if the current controller is "foo/bar/baz" and controller: "baz/bat"
        # is specified, the controller becomes "foo/baz/bat"
        def use_relative_controller!
          if !named_route && different_controller? && !controller.start_with?("/")
            old_parts = current_controller.split('/')
            size = controller.count("/") + 1
            parts = old_parts[0...-size] << controller
            @options[:controller] = parts.join("/")
          end
        end

        # Remove leading slashes from controllers
        def normalize_controller!
          @options[:controller] = controller.sub(%r{^/}, '') if controller
        end

        # Move 'index' action from options to recall
        def normalize_action!
          if @options[:action] == 'index'
            @recall[:action] = @options.delete(:action)
          end
        end

        # Generates a path from routes, returns [path, params].
        # If no route is generated the formatter will raise ActionController::UrlGenerationError
        def generate
          @set.formatter.generate(named_route, options, recall, PARAMETERIZE)
        end

        def different_controller?
          return false unless current_controller
          controller.to_param != current_controller.to_param
        end

        private
          def named_route_exists?
            named_route && set.named_routes[named_route]
          end

          def segment_keys
            set.named_routes[named_route].segment_keys
          end
      end

      # Generate the path indicated by the arguments, and return an array of
      # the keys that were not used to generate it.
      def extra_keys(options, recall={})
        generate_extras(options, recall).last
      end

      def generate_extras(options, recall={})
        path, params = generate(options, recall)
        return path, params.keys
      end

      def generate(options, recall = {})
        Generator.new(options, recall, self).generate
      end

      RESERVED_OPTIONS = [:host, :protocol, :port, :subdomain, :domain, :tld_length,
                          :trailing_slash, :anchor, :params, :only_path, :script_name,
                          :original_script_name]

      def mounted?
        false
      end

      def optimize_routes_generation?
        !mounted? && default_url_options.empty?
      end

      def find_script_name(options)
        options.delete :script_name
      end

      # The +options+ argument must be a hash whose keys are *symbols*.
      def url_for(options)
        options = default_url_options.merge options

        user = password = nil

        if options[:user] && options[:password]
          user     = options.delete :user
          password = options.delete :password
        end

        recall  = options.delete(:_recall) { {} }

        original_script_name = options.delete(:original_script_name)
        script_name = find_script_name options

        if script_name && original_script_name
          script_name = original_script_name + script_name
        end

        path_options = options.dup
        RESERVED_OPTIONS.each { |ro| path_options.delete ro }

        path, params = generate(path_options, recall)

        if options.key? :params
          params.merge! options[:params]
        end

        options[:path]        = path
        options[:script_name] = script_name
        options[:params]      = params
        options[:user]        = user
        options[:password]    = password

        ActionDispatch::Http::URL.url_for(options)
      end

      def call(env)
        req = request_class.new(env)
        req.path_info = Journey::Router::Utils.normalize_path(req.path_info)
        @router.serve(req)
      end

      def recognize_path(path, environment = {})
        method = (environment[:method] || "GET").to_s.upcase
        path = Journey::Router::Utils.normalize_path(path) unless path =~ %r{://}
        extras = environment[:extras] || {}

        begin
          env = Rack::MockRequest.env_for(path, {:method => method})
        rescue URI::InvalidURIError => e
          raise ActionController::RoutingError, e.message
        end

        req = request_class.new(env)
        @router.recognize(req) do |route, params|
          params.merge!(extras)
          params.each do |key, value|
            if value.is_a?(String)
              value = value.dup.force_encoding(Encoding::BINARY)
              params[key] = URI.parser.unescape(value)
            end
          end
          old_params = req.path_parameters
          req.path_parameters = old_params.merge params
          app = route.app
          if app.matches?(req) && app.dispatcher?
            dispatcher = app.app

            if dispatcher.controller(params, false)
              dispatcher.prepare_params!(params)
              return params
            else
              raise ActionController::RoutingError, "A route matches #{path.inspect}, but references missing controller: #{params[:controller].camelize}Controller"
            end
          end
        end

        raise ActionController::RoutingError, "No route matches #{path.inspect}"
      end
    end
  end
end

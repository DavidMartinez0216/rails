*   Allow nested access to `secrets.yml` keys via method calls

    Previously only top level keys loaded in `secrets.yml` were accessible
    with method calls. Now any key, however nested, can be accessed with
    method calls.

    If the following `secrets.yml` file is loaded:

    ```yml
    # config/secrets.yml
    development:
      payment_options:
        gateway: stripe
    ```

    `Rails.application.secrets.payment_options.gateway` will now return the same thing as `Rails.application.config.secrets.payment_options[:gateway]`

    *Ghouse Mohamed*

*   Add JavaScript dependencies installation on bin/setup

    Add  `yarn install` to bin/setup when using esbuild, webpack, or rollout.

    *Carlos Ribeiro*

*   Use `controller_class_path` in `Rails::Generators::NamedBase#route_url`

    The `route_url` method now returns the correct path when generating
    a namespaced controller with a top-level model using `--model-name`.

    Previously, when running this command:

    ``` sh
    bin/rails generate scaffold_controller Admin/Post --model-name Post
    ```

    the comments above the controller action would look like:

    ``` ruby
    # GET /posts
    def index
      @posts = Post.all
    end
    ```

    afterwards, they now look like this:

    ``` ruby
    # GET /admin/posts
    def index
      @posts = Post.all
    end
    ```

    Fixes #44662.

    *Andrew White*

*   No longer add autoloaded paths to `$LOAD_PATH`.

    This means it won't be possible to load them with a manual `require` call, the class or module can be referenced instead.

    Reducing the size of `$LOAD_PATH` speed-up `require` calls for apps not using `bootsnap`, and reduce the
    size of the `bootsnap` cache for the others.

    *Jean Boussier*

*   Remove default `X-Download-Options` header

    This header is currently only used by Internet Explorer which
    will be discontinued in 2022 and since Rails 7 does not fully
    support Internet Explorer this header should not be a default one.

    *Harun Sabljaković*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/railties/CHANGELOG.md) for previous changes.

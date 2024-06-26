*   Include closing `</form>` tag when calling `form_tag` and `form_with` without a block:

    ```ruby
    config.action_view.closes_form_tag_without_block = true

    form_tag "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields --></form>

    form_with url: "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields --></form>

    config.action_view.closes_form_tag_without_block = false

    form_tag "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields -->

    form_with url: "https://example.com"
    # => <form action="https://example.com" method="post"><!-- Rails-generated hidden fields -->
    ```

    *Sean Doyle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.

*   Add support for multiple databases for Action Text.

    `config.action_text.connects_to = { writing: :primary, reading: :primary_replica }`

    *Matthew Nguyen*

*   Rename `rich_text_area` methods into `rich_textarea`

    Old names are still available as aliases.

    *Sean Doyle*


*   Only sanitize `content` attribute when present in attachments.

    *Petrik de Heus*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actiontext/CHANGELOG.md) for previous changes.

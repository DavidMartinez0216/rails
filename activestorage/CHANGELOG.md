*   Add support for combining predefined variations

    Sometimes you will want to combine predefined variants, like rotate a thumb:
    `@user.avatar.variant(:thumb, rotate: 90)`

    *Marek de Heus*

*   Improve `ActiveStorage::Filename#sanitized` method to handle special characters more effectively.
    Replace the characters `"*?<>` with `-` if they exist in the Filename to match the Filename convention of Win OS.

    *Luong Viet Dung(Martin)*

*   Improve InvariableError, UnpreviewableError and UnrepresentableError message.

    Include Blob ID and content_type in the messages.

    *Petrik de Heus*

*   Mark proxied files as `immutable` in their Cache-Control header

    *Nate Matykiewicz*


Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activestorage/CHANGELOG.md) for previous changes.

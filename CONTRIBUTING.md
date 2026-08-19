# Contributing

Bug reports and focused pull requests are welcome.

## Requirements

- macOS 15 or later
- Xcode with Swift 6 support

## Local checks

```sh
make test
make verify
```

`make test` runs the unit and Carbon integration tests. `make verify` also builds and validates the universal Release app.

## Project conventions

- Keep Silent Switch a background app with no Dock icon, menu bar item, overlay, or notifications.
- Register only configured top-row digit shortcuts. Do not inspect unrelated keyboard input.
- Preserve the Carbon lifecycle: register hotkeys before installing the dispatcher event handler.
- Keep user-facing strings in `SilentSwitch/Resources/Localizable.xcstrings` and update both Chinese and English.
- Add a regression test for every behavior fix.

Use a concise [Conventional Commit](https://www.conventionalcommits.org/) message for commits.

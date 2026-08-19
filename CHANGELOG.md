# Changelog

All notable changes to Silent Switch are documented here.

## 1.0.8 — 2026-08-19

- Fixed global hotkeys not firing on some Macs by registering Carbon hotkeys before installing the dispatcher handler.
- Kept hotkey registrations stable while settings change, the Mac wakes, or the user session becomes active.
- Prevented an older app-activation retry from overriding a newer shortcut press.
- Added activation verification, stuck-key recovery, and focused diagnostic logging.
- Added universal release verification, CI, notarization checks, and SHA-256 release checksums.

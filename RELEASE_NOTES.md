# Stats Neo v1.0.1

Stats Neo 1.0.1 improves the application-window lifecycle while preserving the menu-bar-first experience introduced in 1.0.0.

## Dock lifecycle

- Opening a program page now switches Stats Neo to a regular macOS application and shows its icon in the Dock.
- Closing the last visible program page restores accessory mode and hides the Dock icon without quitting the menu-bar process.
- Settings, first-run setup, update, and support windows participate in the lifecycle.
- Combined and standalone module popovers remain menu-bar popovers and do not show the Dock icon by themselves.
- When multiple program pages are visible, closing one page keeps the Dock icon until the final page closes.

## Compatibility

- Existing preferences, Bundle ID, menu-bar modules, Combined configuration, widgets, and update path remain compatible with 1.0.0.
- Universal application for Apple Silicon and Intel.
- macOS 12 or newer.

## Verification

- Opening Settings was verified to change the running application's activation policy to `regular`.
- Closing Settings was verified to restore the activation policy to `accessory` while the menu-bar process remained running.
- SwiftLint and all 41 localization files pass their repository checks.
- Release and Debug builds, stable XCTest suite, standalone Intel/ARM SMC tests, universal architecture, signature verification, and package inspection are release gates.

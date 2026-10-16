# Stats Neo v1.0.0

Stats Neo 1.0.0 is the first formal release of the independent Stats Neo line, derived from upstream Stats 3.0.21.

## New identity

- User-facing application name changed to **Stats Neo**.
- Release assets changed to `Stats Neo.dmg` and `Stats Neo.app.zip`.
- Repository, update checks, release notes, support, and bug-report links point to `BianZhongMing/Stats-Neo`.
- The original Bundle ID and settings domain are retained so existing Stats-derived preferences continue to work after upgrading.

## Combined experience

- Redesigned compact Combined panel with translucent system material and independent system/light/dark appearance.
- First-run wizard recommends **Combined modules (Recommended)**.
- Default Combined components: CPU, memory, disk, network, and battery.
- Menu-bar upload/download speed display is enabled by default.
- Remote is disabled by default and excluded from Combined on clean installations.
- Components can be selected and reordered independently of standalone modules.

## Module presentation

- CPU shows user/system percentages and a stacked history chart.
- Memory and disk use consistent ring sizes and aligned metrics.
- Network shows upload/download values above a full-width dual-series history chart.
- Battery shows percentage, charging state, time to full, cycles, and max capacity; mAh is available by hovering the max-capacity percentage.
- Battery badges for low power, charging, optimized charging paused, fully charged, and plugged-in states are kept within compact view bounds in both light and dark modes.

## Performance and energy

- Reader results are delivered only to real consumers.
- Hidden popups, previews, and portals no longer maintain unnecessary high-frequency histories.
- Pure Combined network-speed mode uses the lightweight interface-counter path and avoids `ps`, `top`, `nettop`, CoreWLAN, location, and public-IP work.
- Performance, balanced, and low-power modes support idle throttling and macOS low-power mode.
- Same-frequency readers share timer buckets and use utility QoS with dynamic tolerance.
- Sampling is non-reentrant and persistence avoids unnecessary JSON encoding.

## Compatibility

- macOS 12 or newer.
- Universal application: Apple Silicon and Intel.
- Upgrade and uninstall scripts recognize both `Stats Neo.app` and the legacy `Stats.app` path.

## Verification

The release is gated on Release/Debug builds, the full available XCTest suite, standalone SMC Intel/ARM tests, script syntax checks, universal architecture, signature verification, package inspection, and a local launch smoke test.

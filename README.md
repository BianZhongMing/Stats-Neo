# Stats Neo

<p align="center">
  <a href="https://github.com/BianZhongMing/Stats-Neo/releases">
    <img src="Stats/Supporting%20Files/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="120" alt="Stats Neo">
  </a>
</p>

**A lightweight, modern macOS system monitor for the menu bar.**

> [!IMPORTANT]
> Stats Neo is an independent derivative of [exelban/stats](https://github.com/exelban/stats), based on upstream version 3.0.21. It preserves the original open-source foundation while focusing on a redesigned Combined panel, lower background energy impact, clearer battery status, and a streamlined first-run experience. The upstream project and its author do not maintain this derivative.

## Highlights

- **Combined-first experience** — the first-run wizard recommends Combined mode with CPU, memory, disk, network, and battery enabled.
- **Independent appearance** — Combined can follow the system or use its own light/dark mode.
- **Glass panel design** — compact translucent panel with consistent charts, spacing, and module separation.
- **Menu-bar network speed** — upload/download values are enabled by default in the recommended Combined preset.
- **Lower energy impact** — readers run only when their data has a real consumer; expensive hidden-detail collection is avoided.
- **Adaptive sampling** — performance, balanced, and low-power modes with automatic idle throttling.
- **Battery A1 display** — percentage inside the battery and complete badges for charging, paused charging, fully charged, plugged in, and low battery.
- **Configurable components** — choose and reorder Combined modules without changing standalone module switches.
- **Remote disabled by default** — Remote remains available, but is not enabled in a clean installation or included in Combined by default.

## What changed from upstream

| Area | Stats Neo |
| --- | --- |
| Combined panel | Independent menu-bar item and settings page; compact iStat-inspired light/dark layout |
| CPU | User/system percentages with stacked history bars |
| Memory | Consistent usage ring with used, available, swap, and pressure values |
| Disk | Consistent usage ring, capacity values, read/write speed, and history bars |
| Network | Upload/download values above a full-width dual-series history chart |
| Battery | Percentage icon, state badge, time to full, cycle count, and max-capacity percentage; hover reveals mAh |
| Energy | Consumer-aware readers, shared timers, adaptive intervals, and non-overlapping sampling |
| First run | Combined dark mode is recommended; CPU, memory, disk, network, and battery are selected |
| Update channel | GitHub Releases from `BianZhongMing/Stats-Neo` |

## Installation

Download the latest release:

- [Stats-Neo.dmg](https://github.com/BianZhongMing/Stats-Neo/releases/latest/download/Stats-Neo.dmg)
- [Stats-Neo.app.zip](https://github.com/BianZhongMing/Stats-Neo/releases/latest/download/Stats-Neo.app.zip)

Open `Stats-Neo.dmg` and drag **Stats Neo.app** to Applications, or extract the ZIP and move the app manually.

> [!NOTE]
> Release assets may use ad-hoc signing when Apple distribution credentials are unavailable. On first launch, macOS may require approval in **System Settings → Privacy & Security**.

### Uninstall

```bash
sh "/Applications/Stats Neo.app/Contents/Resources/Scripts/uninstall.sh"
```

The uninstaller also recognizes the legacy `Stats.app` path for upgrade compatibility.

## Usage

1. Open **Stats Neo Settings → Combined**.
2. Enable or disable the menu-bar network speed display.
3. Select the Combined appearance: system, light, or dark.
4. Choose components and drag rows to reorder them.
5. Select an energy mode: performance, balanced, or low power.
6. Click the Stats Neo menu-bar item to open the Combined panel.

## Requirements

- macOS 12 Monterey or newer
- Apple Silicon or Intel Mac

## Development

Open `Stats.xcodeproj` and build the existing `Stats` scheme. The scheme and internal target identifiers intentionally retain their upstream names to preserve compatibility; the produced application is **Stats Neo.app**.

Useful checks:

```bash
xcodebuild -project Stats.xcodeproj -scheme Stats -configuration Release build
xcodebuild -project Stats.xcodeproj -scheme Stats test
python3 Kit/scripts/run-smc-tests.py
```

## Project links

- Repository: https://github.com/BianZhongMing/Stats-Neo
- Bug reports: https://github.com/BianZhongMing/Stats-Neo/issues
- Releases: https://github.com/BianZhongMing/Stats-Neo/releases

## Upstream and license

Stats Neo inherits from [exelban/stats](https://github.com/exelban/stats). Original copyright and attribution are preserved in the source files.

Distributed under the [MIT License](LICENSE).

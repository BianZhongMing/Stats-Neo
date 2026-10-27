# Stats Neo v1.0.2

Stats Neo 1.0.2 fixes truncated upload and download values in the Combined menu-bar network-speed display.

## Combined network-speed display

- Upload and download values now size their value column from the actual formatted text instead of relying on a fixed-width slot.
- Longer values such as `11.9 MB/s` remain fully visible rather than losing their trailing unit characters.
- The two-row display uses the longer of the upload and download strings so both rows fit consistently.
- Short values retain the existing compact minimum width.
- Dynamic sizing is enabled only for the dedicated Combined network-speed widget; standalone Network widgets keep their existing layout.

## Compatibility

- Existing preferences, Bundle ID, Combined configuration, standalone modules, widgets, and update path remain compatible with 1.0.1.
- Universal application for Apple Silicon and Intel.
- macOS 12 or newer.

## Verification

- Dedicated width tests cover short values, long values, and selection of the longer upload/download row.
- The stable Kit regression suite passes with the upstream legacy beta-version assertions excluded as an existing baseline issue.
- Release builds, localization checks, SMC Intel/ARM tests, universal architecture, signature verification, and package inspection remain release gates.

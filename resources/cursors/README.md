# ZirconOS Classic Cursor Set

Original classic-style cursor designs for the ZirconOS Classic (Windows 2000) desktop theme.

## Design Language

All cursors follow the **Windows 2000 Classic** aesthetic:

- **Color**: Black outline with white fill — no gradients or glass effects
- **Size**: 12x19 pixels (standard arrow), designed on 32x32 SVG viewBox
- **Style**: Pixel-perfect, no anti-aliasing, sharp 1px edges
- **Format**: SVG with `viewBox="0 0 32 32"` (32x32 logical pixels)

## Cursor Files

| File | Type | Description |
|------|------|-------------|
| `classic_arrow.svg` | Default pointer | Standard black-and-white arrow pointer |
| `classic_hand.svg` | Link / hand | Pointing hand cursor for clickable elements |
| `classic_ibeam.svg` | Text / I-beam | I-beam cursor for text selection areas |
| `classic_wait.svg` | Busy / wait | Hourglass cursor indicating busy state |
| `classic_size_ns.svg` | Vertical resize | Double-headed vertical arrow for window resize |
| `classic_size_ew.svg` | Horizontal resize | Double-headed horizontal arrow for window resize |
| `classic_move.svg` | Move | Four-directional arrow cross for drag/move |

## Cursor Mapping

Standard cursor names to ZirconOS Classic file mapping:

```
default          -> classic_arrow.svg
pointer          -> classic_hand.svg
text             -> classic_ibeam.svg
wait             -> classic_wait.svg
ns-resize        -> classic_size_ns.svg
ew-resize        -> classic_size_ew.svg
move             -> classic_move.svg
```

## Technical Notes

- Black outline color: `#000000`
- White fill color: `#FFFFFF`
- Hot spot: top-left corner (0, 0) for arrow; tip of finger for hand
- No SVG filters or effects — pure path-based shapes
- Compatible with standard SVG renderers and direct bitmap conversion

## Copyright

Copyright (C) 2024-2026 ZirconOS Project
Licensed under GNU Lesser General Public License v2.1

These cursor designs are **original creations** for ZirconOS and are NOT derived from,
copied from, or affiliated with any Microsoft Corporation products or any other
third-party cursor sets.

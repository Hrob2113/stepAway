# StepAway

A menu bar app for macOS that keeps your eyes from seizing up — the 20-20-20 rule,
enforced gently: every 20 minutes, look at something 20 feet away for 20 seconds.

## What it does

- **Work/break timer** with three rhythms (Balanced, Relaxed, Intensive) or your own intervals
- **Full-screen break overlay** — frosted glass over your blurred desktop, with an animated
  cue for what to actually do: eyes that follow your pointer and blink on short breaks,
  a figure standing and stretching on long ones
- **Gentle nudges** between breaks to sit tall and to blink
- **Knows when you step away** — if you're idle long enough it pauses, and asks whether
  you rested when you come back
- **Pause** for 30 minutes, an hour, or until tomorrow

## Design

Monochrome throughout — white, grey and black, no colour anywhere. Every background is a
real backdrop blur rather than a tinted panel, built on macOS 26's Liquid Glass.

## Requirements

macOS 26.2 or later. The interface is built on Liquid Glass (`glassEffect`), which is
macOS 26-only.

## Building

```sh
open StepAway.xcodeproj
```

Build and run. The target uses a file-system-synchronized group, so any `.swift` file added
under `StepAway/` is compiled automatically — no project file edits needed.

## Architecture

| File | Role |
|---|---|
| `StepAwayApp.swift` | `@main` app, `MenuBarExtra`, app delegate |
| `BreakManager.swift` | Timer engine, idle detection, notifications |
| `AppSettings.swift` | `@Observable` settings, presets, persistence |
| `OverlayPresenter.swift` | All window management for overlays |
| `Theme.swift` | Palette, motion, the shared frosted-glass treatment |
| `Glyphs.swift` | Animated eye, stretch and posture vectors |
| `Hourglass.swift` | The draining hourglass |

Timers are **deadline-based** rather than accumulated, so they survive system sleep without
drift. Idle detection reads `CGEventSource` directly, which means the app needs no
accessibility permission.

## Contributing

Code standards are in [STYLE.md](STYLE.md).

## Licence

MIT

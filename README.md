# focusbeam

A minimal macOS menu bar utility for better privacy when working in public: it dims the whole screen except a beam of light that follows your cursor.

Focusbeam pairs well with privacy screens and further reduces what's visible to someone sitting next to you on an airplane or peeking over your shoulder.

Intentionally simple:
- Single Swift file, AppKit only, no dependencies.
- No Accessibility, Screen Recording, or any other permissions required.

## Install

### Homebrew (coming)

### From source

```sh
git clone https://github.com/v4fs/focusbeam && cd focusbeam
swift build -c release
.build/release/focusbeam &
```

## Usage

A flashlight icon appears in the menu bar (no Dock icon):

- **Left-click** the icon — toggle the beam on/off.
- **Scroll** over the icon — grow/shrink the beam.
- **Right-click** the icon — menu with **Size**, **Darkness**, and
  **Sharpness** (soft feather ↔ hard edge) sliders (settings persist across
  launches) and Quit.

The overlay covers the main display (the one with the menu bar) and stays on
across Spaces and over full-screen apps. The menu bar itself is kept visible
so you can always reach the toggle.

## Limitations

- The overlay shows up in screenshots and screen sharing

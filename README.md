# Switcher

A free, open-source window switcher for macOS. Press **Option+Tab** to see all your open windows and quickly switch between them.

## Installation

1. Download the latest release from [Releases](https://github.com/rogedev/switcher/releases)
2. Unzip it and drag **Switcher.app** to your **Applications** folder
3. **First launch — clear the macOS security warning.** Switcher is open-source and isn't
   signed with a paid Apple Developer certificate, so on first open macOS Gatekeeper shows
   *"Apple could not verify Switcher is free of malware…"*. Remove the download quarantine
   flag once and it opens normally from then on:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Switcher.app
   ```

   Then open Switcher from Applications. _Alternatively:_ try to open it, then go to
   **System Settings → Privacy & Security**, scroll to the *Security* section, and click
   **"Open Anyway"**.
4. Switcher appears as an icon in your menu bar
5. Grant the permissions it asks for (see below)

## Permissions

Switcher needs two macOS permissions to work:

| Permission | Why |
|---|---|
| **Accessibility** | To focus and raise windows when you select them |
| **Screen Recording** | To show window titles and thumbnail previews |

On first launch, macOS will prompt you to grant these. Go to **System Settings > Privacy & Security** and enable Switcher under both **Accessibility** and **Screen & System Audio Recording**.

## How to Use

| Shortcut | Action |
|---|---|
| **⌥ Tab** | Open switcher / cycle forward |
| **⌥ ⇧ Tab** | Cycle backward |
| **Arrow keys** | Navigate the grid |
| **Release ⌥** | Switch to the selected window |
| **Escape** | Cancel |

Hold Option, tap Tab to cycle through windows, release Option to switch. That's it.

## Building from Source

Requires macOS 13+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Switcher.xcodeproj -scheme Switcher build
```

## License

MIT

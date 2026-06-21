import Cocoa

class StatusBarController: NSObject, NSMenuDelegate {
  var onQuit: (() -> Void)?
  var onSetModifier: ((HotkeyModifier) -> Void)?
  var onSetDisplayMode: ((DisplayMode) -> Void)?

  private var statusItem: NSStatusItem!
  private var permissionItem: NSMenuItem!
  private var accessibilityItem: NSMenuItem!
  private var optionItem: NSMenuItem!
  private var commandItem: NSMenuItem!
  private var iconItem: NSMenuItem!
  private var previewItem: NSMenuItem!

  override init() {
    super.init()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem.button {
      button.image =
        NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Switcher")
        ?? makeDefaultIcon()
      button.image?.isTemplate = true
    }

    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(
      NSMenuItem(title: "About Switcher", action: #selector(showAbout), keyEquivalent: ""))
    menu.addItem(.separator())

    let shortcutMenu = NSMenu()
    optionItem = NSMenuItem(
      title: "⌥ Tab", action: #selector(selectModifier(_:)), keyEquivalent: "")
    optionItem.representedObject = HotkeyModifier.option
    commandItem = NSMenuItem(
      title: "⌘ Tab", action: #selector(selectModifier(_:)), keyEquivalent: "")
    commandItem.representedObject = HotkeyModifier.command
    optionItem.target = self
    commandItem.target = self
    shortcutMenu.addItem(optionItem)
    shortcutMenu.addItem(commandItem)
    let shortcutItem = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
    shortcutItem.submenu = shortcutMenu
    menu.addItem(shortcutItem)

    let displayMenu = NSMenu()
    iconItem = NSMenuItem(
      title: "App Icons", action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
    iconItem.representedObject = DisplayMode.icon
    previewItem = NSMenuItem(
      title: "Window Previews", action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
    previewItem.representedObject = DisplayMode.preview
    iconItem.target = self
    previewItem.target = self
    displayMenu.addItem(iconItem)
    displayMenu.addItem(previewItem)
    let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
    displayItem.submenu = displayMenu
    menu.addItem(displayItem)

    menu.addItem(.separator())

    accessibilityItem = NSMenuItem(
      title: "Grant Accessibility...", action: #selector(grantAccessibility), keyEquivalent: ""
    )

    accessibilityItem.target = self

    menu.addItem(accessibilityItem)

    permissionItem = NSMenuItem(
      title: "Grant Screen Recording...", action: #selector(grantScreenRecording), keyEquivalent: ""
    )
    permissionItem.target = self
    menu.addItem(permissionItem)

    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

    for item in menu.items where item.action != nil && item.target == nil {
      item.target = self
    }

    statusItem.menu = menu
  }

  func menuWillOpen(_ menu: NSMenu) {
    let modifier = Settings.hotkeyModifier
    optionItem.state = modifier == .option ? .on : .off
    commandItem.state = modifier == .command ? .on : .off

    let mode = Settings.displayMode
    iconItem.state = mode == .icon ? .on : .off
    previewItem.state = mode == .preview ? .on : .off

    if Permissions.checkAccessibility() {
      accessibilityItem.title = "Accessibility: Enabled"
      accessibilityItem.action = nil
    } else {
      accessibilityItem.title = "Grant Accessibility... (required)"
      accessibilityItem.action = #selector(grantAccessibility)
    }

    if Permissions.checkScreenRecording() {
      permissionItem.title = "Screen Recording: Enabled"
      permissionItem.action = nil
    } else {
      permissionItem.title = "Grant Screen Recording..."
      permissionItem.action = #selector(grantScreenRecording)
    }
  }

  @objc private func selectModifier(_ sender: NSMenuItem) {
    if let modifier = sender.representedObject as? HotkeyModifier {
      onSetModifier?(modifier)
    }
  }

  @objc private func selectDisplayMode(_ sender: NSMenuItem) {
    if let mode = sender.representedObject as? DisplayMode {
      onSetDisplayMode?(mode)
    }
  }

  @objc private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "Switcher"
    alert.informativeText =
      "A free, open-source window switcher for macOS"
    alert.alertStyle = .informational
    alert.runModal()
  }

  @objc private func grantAccessibility() {
    if !Permissions.ensureAccessibility() {
      openAccessibilitySettings()
    }
  }

  private func openAccessibilitySettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func grantScreenRecording() {
    Permissions.requestScreenRecording()
  }

  @objc private func quit() {
    onQuit?()
  }

  private func makeDefaultIcon() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    return NSImage(size: size, flipped: false) { _ in
      let path = NSBezierPath(
        roundedRect: NSRect(x: 1, y: 4, width: 10, height: 10), xRadius: 2, yRadius: 2)
      path.lineWidth = 1.2
      NSColor.labelColor.setStroke()
      path.stroke()
      let path2 = NSBezierPath(
        roundedRect: NSRect(x: 6, y: 1, width: 10, height: 10), xRadius: 2, yRadius: 2)
      path2.lineWidth = 1.2
      path2.stroke()
      return true
    }
  }
}

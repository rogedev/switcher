import Cocoa

class StatusBarController: NSObject, NSMenuDelegate {
  var onQuit: (() -> Void)?

  private var statusItem: NSStatusItem!
  private var permissionItem: NSMenuItem!

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
    menu.addItem(NSMenuItem(title: "About Switcher", action: #selector(showAbout), keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Shortcut: ⌥ Tab", action: nil, keyEquivalent: ""))
    menu.addItem(.separator())

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
    if Permissions.checkScreenRecording() {
      permissionItem.title = "Screen Recording: Enabled"
      permissionItem.action = nil
    } else {
      permissionItem.title = "Grant Screen Recording..."
      permissionItem.action = #selector(grantScreenRecording)
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

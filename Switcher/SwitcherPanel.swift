import Cocoa

class SwitcherPanel: NSPanel {
  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )

    level = .popUpMenu
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
  }

  override var canBecomeKey: Bool { true }
}

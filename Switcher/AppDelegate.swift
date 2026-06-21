import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusBar: StatusBarController!
  private var hotkey: GlobalHotkey!
  private var windowManager: WindowManager!
  private var switcherPanel: SwitcherPanel!
  private var switcherView: SwitcherView!
  private var previousApp: NSRunningApplication?

  func applicationDidFinishLaunching(_ notification: Notification) {
    windowManager = WindowManager()
    switcherView = SwitcherView()
    switcherView.onSelect = { [weak self] window in
      self?.hideSwitcher(focusWindow: window)
    }
    switcherPanel = SwitcherPanel()
    switcherPanel.contentView = switcherView

    statusBar = StatusBarController()
    statusBar.onQuit = {
      NSApp.terminate(nil)
    }

    hotkey = GlobalHotkey()
    hotkey.onActivate = { [weak self] in
      self?.showSwitcher()
    }
    hotkey.onCycleNext = { [weak self] in
      self?.switcherView.cycleSelection(forward: true)
    }
    hotkey.onCyclePrev = { [weak self] in
      self?.switcherView.cycleSelection(forward: false)
    }
    hotkey.onRelease = { [weak self] in
      guard let self, let window = self.switcherView.selectedWindow else { return }
      self.hideSwitcher(focusWindow: window)
    }
    hotkey.onCancel = { [weak self] in
      self?.hideSwitcher(focusWindow: nil)
    }

    hotkey.register()

    if !Permissions.checkAccessibility() {
      Permissions.ensureAccessibility()
    }

    if !Permissions.checkScreenRecording() {
      Permissions.requestScreenRecording()
    }
  }

  private func showSwitcher() {
    guard !switcherPanel.isVisible else {
      switcherView.cycleSelection(forward: true)
      return
    }

    previousApp = NSWorkspace.shared.frontmostApplication

    let windows = windowManager.getWindows()
    guard !windows.isEmpty else { return }

    switcherView.update(windows: windows)
    switcherView.selectIndex(0)

    if #available(macOS 14.0, *) {
      for (i, window) in windows.enumerated() where window.thumbnail == nil {
        ThumbnailCapture.captureAsync(windowID: window.windowID) { [weak self] image in
          guard let image else { return }
          self?.switcherView.updateThumbnail(at: i, image: image)
        }
      }
    }

    let screen = screenWithMouse()
    let idealSize = switcherView.idealSize(for: screen)

    switcherPanel.setContentSize(idealSize)
    let screenFrame = screen.frame
    let panelX = screenFrame.midX - idealSize.width / 2
    let panelY = screenFrame.midY - idealSize.height / 2
    switcherPanel.setFrameOrigin(NSPoint(x: panelX, y: panelY))

    switcherPanel.makeKeyAndOrderFront(nil)
    switcherPanel.alphaValue = 0
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.15
      switcherPanel.animator().alphaValue = 1
    }
  }

  private func hideSwitcher(focusWindow: WindowInfo?) {
    NSAnimationContext.runAnimationGroup(
      { ctx in
        ctx.duration = 0.1
        switcherPanel.animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        self?.switcherPanel.orderOut(nil)
      })

    if let window = focusWindow {
      windowManager.focus(window: window)
    } else if let prev = previousApp {
      prev.activate()
    }
    previousApp = nil
  }

  private func screenWithMouse() -> NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
      ?? NSScreen.main
      ?? NSScreen.screens[0]
  }
}

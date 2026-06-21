import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusBar: StatusBarController!
  private var hotkey: GlobalHotkey!
  private var windowManager: WindowManager!
  private var switcherPanel: SwitcherPanel!
  private var switcherView: SwitcherView!
  private var previousApp: NSRunningApplication?
  private var hotkeyRetryTimer: Timer?
  private var didRequestScreenRecording = false

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
    statusBar.onSetModifier = { [weak self] modifier in
      Settings.hotkeyModifier = modifier
      self?.hotkey.modifier = modifier
    }
    statusBar.onSetDisplayMode = { [weak self] mode in
      Settings.displayMode = mode
      if mode == .preview {
        self?.requestScreenRecordingIfNeeded()
      }
    }

    hotkey = GlobalHotkey()
    hotkey.modifier = Settings.hotkeyModifier
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

    if !Permissions.checkAccessibility() {
      Permissions.ensureAccessibility()
    }


    if !hotkey.register() {
      hotkeyRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
        [weak self] timer in
        if self?.hotkey.register() == true {
          timer.invalidate()
          self?.hotkeyRetryTimer = nil
        }
      }
    }
  }

  private func showSwitcher() {
    guard !switcherPanel.isVisible else {
      switcherView.cycleSelection(forward: true)
      return
    }

    previousApp = NSWorkspace.shared.frontmostApplication

    let displayMode = Settings.displayMode
    let windows = windowManager.getWindows(displayMode: displayMode)
    guard !windows.isEmpty else { return }

    switcherView.update(windows: windows, displayMode: displayMode)
    switcherView.selectIndex(0)

    if displayMode == .preview, #available(macOS 14.0, *) {
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

  // Screen Recording is only needed for previews.
  private func requestScreenRecordingIfNeeded() {
    if Permissions.checkScreenRecording() { return }

    if didRequestScreenRecording {
      promptRelaunchForPreviews()
      return
    }

    didRequestScreenRecording = true
    Permissions.requestScreenRecording()
  }

  private func promptRelaunchForPreviews() {
    let alert = NSAlert()
    alert.messageText = "Relaunch to enable Window Previews"
    alert.informativeText =
      "Enable Switcher under Screen & System Audio Recording in System Settings, "
      + "then relaunch Switcher for previews to take effect."
    alert.addButton(withTitle: "Relaunch Now")
    alert.addButton(withTitle: "Later")
    NSApp.activate(ignoringOtherApps: true)

    if alert.runModal() == .alertFirstButtonReturn {
      relaunch()
    }
  }

  private func relaunch() {
    let config = NSWorkspace.OpenConfiguration()
    config.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
      DispatchQueue.main.async { NSApp.terminate(nil) }
    }
  }

  private func screenWithMouse() -> NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
      ?? NSScreen.main
      ?? NSScreen.screens[0]
  }
}

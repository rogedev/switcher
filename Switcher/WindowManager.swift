import ApplicationServices
import Cocoa

struct WindowInfo {
  let windowID: CGWindowID
  let title: String
  let appName: String
  let appIcon: NSImage?
  let pid: pid_t
  let bounds: CGRect
  let isMinimized: Bool
  var thumbnail: NSImage?
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

class WindowManager {
  func getWindows(displayMode: DisplayMode) -> [WindowInfo] {
    guard
      let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else {
      return []
    }

    let apps = NSWorkspace.shared.runningApplications
    let appsByPID = Dictionary(
      apps.map { ($0.processIdentifier, $0) },
      uniquingKeysWith: { first, _ in first })
    let myPID = ProcessInfo.processInfo.processIdentifier

    var axTitles: [CGWindowID: String] = [:]
    var axWindowIDs = Set<CGWindowID>()
    var axQueriedPIDs = Set<pid_t>()
    var minimized: [(windowID: CGWindowID, title: String, app: NSRunningApplication)] = []
    for app in apps
    where app.activationPolicy == .regular && app.processIdentifier != myPID
      && !app.isTerminated
    {
      collectAXWindows(
        for: app, titles: &axTitles, axWindowIDs: &axWindowIDs,
        axQueriedPIDs: &axQueriedPIDs, minimized: &minimized)
    }

    var windows: [WindowInfo] = []
    var seenIDs = Set<CGWindowID>()

    for info in windowList {
      guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
        let pid = info[kCGWindowOwnerPID as String] as? pid_t,
        pid != myPID,
        let layer = info[kCGWindowLayer as String] as? Int,
        layer == 0
      else {
        continue
      }

      let boundsDict = info[kCGWindowBounds as String] as? [String: Any]
      let bw = (boundsDict?["Width"] as? NSNumber)?.doubleValue ?? 0
      let bh = (boundsDict?["Height"] as? NSNumber)?.doubleValue ?? 0
      guard bw > 50, bh > 50 else { continue }

      let app = appsByPID[pid]
      guard app?.activationPolicy == .regular else { continue }

      if axQueriedPIDs.contains(pid) && !axWindowIDs.contains(windowID) {
        continue
      }

      let bx = (boundsDict?["X"] as? NSNumber)?.doubleValue ?? 0
      let by = (boundsDict?["Y"] as? NSNumber)?.doubleValue ?? 0
      let bounds = CGRect(x: bx, y: by, width: bw, height: bh)

      let ownerName =
        (info[kCGWindowOwnerName as String] as? String) ?? app?.localizedName ?? "Unknown"
      let cgTitle = (info[kCGWindowName as String] as? String) ?? ""
      let axTitle = axTitles[windowID] ?? ""
      let resolved = axTitle.isEmpty ? cgTitle : axTitle
      let displayTitle = resolved.isEmpty ? ownerName : resolved

      // Previews require Screen Recording; icon mode skips capture entirely so
      // the tile falls back to the app icon.
      let thumbnail =
        displayMode == .preview
        ? ThumbnailCapture.capture(
          windowID: windowID, maxSize: CGSize(width: 440, height: 280))
        : nil

      windows.append(
        WindowInfo(
          windowID: windowID,
          title: displayTitle,
          appName: ownerName,
          appIcon: app?.icon,
          pid: pid,
          bounds: bounds,
          isMinimized: false,
          thumbnail: thumbnail
        ))
      seenIDs.insert(windowID)
    }

    // Minimized windows weren't in the on-screen list; append those not yet shown.
    for entry in minimized where !seenIDs.contains(entry.windowID) {
      let appName = entry.app.localizedName ?? "Unknown"
      let displayTitle = entry.title.isEmpty ? appName : entry.title
      windows.append(
        WindowInfo(
          windowID: entry.windowID,
          title: displayTitle,
          appName: appName,
          appIcon: entry.app.icon,
          pid: entry.app.processIdentifier,
          bounds: .zero,
          isMinimized: true,
          thumbnail: nil
        ))
      seenIDs.insert(entry.windowID)
    }

    return windows
  }

  private func collectAXWindows(
    for app: NSRunningApplication,
    titles: inout [CGWindowID: String],
    axWindowIDs: inout Set<CGWindowID>,
    axQueriedPIDs: inout Set<pid_t>,
    minimized: inout [(windowID: CGWindowID, title: String, app: NSRunningApplication)]
  ) {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.25)

    var windowsRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        == .success,
      let axWindows = windowsRef as? [AXUIElement]
    else {
      return
    }

    axQueriedPIDs.insert(app.processIdentifier)

    for axWindow in axWindows {
      var windowID: CGWindowID = 0
      guard _AXUIElementGetWindow(axWindow, &windowID) == .success, windowID != 0 else {
        continue
      }

      // Only standard windows belong in the switcher.
      var subroleRef: CFTypeRef?
      AXUIElementCopyAttributeValue(axWindow, kAXSubroleAttribute as CFString, &subroleRef)
      if let subrole = subroleRef as? String,
        subrole != (kAXStandardWindowSubrole as String)
      {
        continue
      }

      axWindowIDs.insert(windowID)

      var titleRef: CFTypeRef?
      AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
      let title = (titleRef as? String) ?? ""
      if !title.isEmpty {
        titles[windowID] = title
      }

      var minimizedRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(
        axWindow, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
        (minimizedRef as? Bool) == true
      {
        minimized.append((windowID, title, app))
      }
    }
  }

  func focus(window: WindowInfo) {
    guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }

    let appElement = AXUIElementCreateApplication(window.pid)
    var windowsRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
      == .success,
      let axWindows = windowsRef as? [AXUIElement]
    {
      for axWindow in axWindows {
        var axWindowID: CGWindowID = 0
        if _AXUIElementGetWindow(axWindow, &axWindowID) == .success,
          axWindowID == window.windowID
        {
          unminimizeIfNeeded(axWindow)
          AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
          app.activate()
          return
        }
      }
      if let axWindow = matchByTitle(axWindows: axWindows, title: window.title) {
        unminimizeIfNeeded(axWindow)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
      }
    }
    app.activate()
  }

  private func unminimizeIfNeeded(_ axWindow: AXUIElement) {
    var minimizedRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef)
      == .success,
      (minimizedRef as? Bool) == true
    {
      AXUIElementSetAttributeValue(
        axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }
  }

  private func matchByTitle(axWindows: [AXUIElement], title: String) -> AXUIElement? {
    for axWindow in axWindows {
      var titleRef: CFTypeRef?
      AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
      if let axTitle = titleRef as? String, axTitle == title {
        return axWindow
      }
    }
    return nil
  }
}

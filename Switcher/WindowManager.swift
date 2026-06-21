import ApplicationServices
import Cocoa

struct WindowInfo {
  let windowID: CGWindowID
  let title: String
  let appName: String
  let appIcon: NSImage?
  let pid: pid_t
  let bounds: CGRect
  var thumbnail: NSImage?
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

class WindowManager {
  func getWindows() -> [WindowInfo] {
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

    var bestPerPID:
      [pid_t: (
        windowID: CGWindowID, title: String, appName: String, bounds: CGRect, area: Double,
        app: NSRunningApplication?
      )] = [:]

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

      let bx = (boundsDict?["X"] as? NSNumber)?.doubleValue ?? 0
      let by = (boundsDict?["Y"] as? NSNumber)?.doubleValue ?? 0
      let bounds = CGRect(x: bx, y: by, width: bw, height: bh)
      let area = bw * bh

      let title = (info[kCGWindowName as String] as? String) ?? ""
      let ownerName =
        (info[kCGWindowOwnerName as String] as? String) ?? app?.localizedName ?? "Unknown"
      let displayTitle = title.isEmpty ? ownerName : title

      if let existing = bestPerPID[pid] {
        if area > existing.area {
          bestPerPID[pid] = (windowID, displayTitle, ownerName, bounds, area, app)
        }
      } else {
        bestPerPID[pid] = (windowID, displayTitle, ownerName, bounds, area, app)
      }
    }

    var windows: [WindowInfo] = []
    for (pid, best) in bestPerPID {
      let thumbnail = ThumbnailCapture.capture(
        windowID: best.windowID, maxSize: CGSize(width: 440, height: 280))
      windows.append(
        WindowInfo(
          windowID: best.windowID,
          title: best.title,
          appName: best.appName,
          appIcon: best.app?.icon,
          pid: pid,
          bounds: best.bounds,
          thumbnail: thumbnail
        ))
    }

    return windows
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
        if _AXUIElementGetWindow(axWindow, &axWindowID) == .success, axWindowID == window.windowID {
          AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
          app.activate()
          return
        }
      }
      if let axWindow = matchByTitle(axWindows: axWindows, title: window.title) {
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
      }
    }
    app.activate()
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

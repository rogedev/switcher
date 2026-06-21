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

            let bx = (boundsDict?["X"] as? NSNumber)?.doubleValue ?? 0
            let by = (boundsDict?["Y"] as? NSNumber)?.doubleValue ?? 0
            let bounds = CGRect(x: bx, y: by, width: bw, height: bh)

            let title = (info[kCGWindowName as String] as? String) ?? ""
            let ownerName =
                (info[kCGWindowOwnerName as String] as? String) ?? app?.localizedName ?? "Unknown"
            let displayTitle = title.isEmpty ? ownerName : title

            let thumbnail = ThumbnailCapture.capture(
                windowID: windowID, maxSize: CGSize(width: 440, height: 280))

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

        for app in apps
        where app.activationPolicy == .regular && app.processIdentifier != myPID
            && !app.isTerminated
        {
            appendMinimizedWindows(for: app, seenIDs: &seenIDs, into: &windows)
        }

        return windows
    }

    private func appendMinimizedWindows(
        for app: NSRunningApplication, seenIDs: inout Set<CGWindowID>,
        into windows: inout [WindowInfo]
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

        for axWindow in axWindows {
            var minimizedRef: CFTypeRef?
            guard
                AXUIElementCopyAttributeValue(
                    axWindow, kAXMinimizedAttribute as CFString, &minimizedRef)
                    == .success,
                (minimizedRef as? Bool) == true
            else {
                continue
            }

            var windowID: CGWindowID = 0
            guard _AXUIElementGetWindow(axWindow, &windowID) == .success, windowID != 0,
                !seenIDs.contains(windowID)
            else {
                continue
            }

            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? ""
            let appName = app.localizedName ?? "Unknown"
            let displayTitle = title.isEmpty ? appName : title

            windows.append(
                WindowInfo(
                    windowID: windowID,
                    title: displayTitle,
                    appName: appName,
                    appIcon: app.icon,
                    pid: app.processIdentifier,
                    bounds: .zero,
                    isMinimized: true,
                    thumbnail: nil
                ))
            seenIDs.insert(windowID)
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

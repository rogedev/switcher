import Cocoa
import ScreenCaptureKit

enum ThumbnailCapture {
  static func capture(windowID: CGWindowID, maxSize: CGSize) -> NSImage? {
    guard
      let cgImage = CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        windowID,
        [.boundsIgnoreFraming, .bestResolution]
      )
    else { return nil }

    let w = CGFloat(cgImage.width)
    let h = CGFloat(cgImage.height)
    guard w > 0, h > 0 else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: w, height: h))
  }

  @available(macOS 14.0, *)
  static func captureAsync(windowID: CGWindowID, completion: @escaping (NSImage?) -> Void) {
    SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) {
      content, error in
      guard let content else {
        DispatchQueue.main.async { completion(nil) }
        return
      }

      guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
        DispatchQueue.main.async { completion(nil) }
        return
      }

      let filter = SCContentFilter(desktopIndependentWindow: scWindow)
      let config = SCStreamConfiguration()
      config.width = min(Int(scWindow.frame.width * 2), 880)
      config.height = min(Int(scWindow.frame.height * 2), 560)
      config.showsCursor = false
      config.captureResolution = .best

      SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, _ in
        var result: NSImage?
        if let image {
          result = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
        DispatchQueue.main.async { completion(result) }
      }
    }
  }
}

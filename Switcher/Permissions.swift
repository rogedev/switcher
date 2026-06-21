import ApplicationServices
import Cocoa

enum Permissions {
  static func checkAccessibility() -> Bool {
    AXIsProcessTrusted()
  }

  @discardableResult
  static func ensureAccessibility() -> Bool {
    if AXIsProcessTrusted() { return true }
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
    return false
  }

  static func checkScreenRecording() -> Bool {
    CGPreflightScreenCaptureAccess()
  }

  static func requestScreenRecording() {
    CGRequestScreenCaptureAccess()
  }
}

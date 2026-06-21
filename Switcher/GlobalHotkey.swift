import Carbon
import Cocoa

class GlobalHotkey {
  typealias Handler = () -> Void

  var onActivate: Handler?
  var onCycleNext: Handler?
  var onCyclePrev: Handler?
  var onRelease: Handler?
  var onCancel: Handler?

  // Read live by the tap callback, so menu changes take effect immediately.
  var modifier: HotkeyModifier = .option

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private(set) var isActive = false


  @discardableResult
  func register() -> Bool {
    guard eventTap == nil else { return true }

    let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
    let selfPtr = Unmanaged.passUnretained(self).toOpaque()

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(mask),
        callback: { _, type, event, refcon in
          guard let refcon else { return Unmanaged.passUnretained(event) }
          let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(refcon).takeUnretainedValue()
          return hotkey.handle(type: type, event: event)
        },
        userInfo: selfPtr
      )
    else {
      return false
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    eventTap = tap
    runLoopSource = source
    return true
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // The system disables the tap if our callback is too slow; just re-enable it.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }

    let modifierHeld = modifierIsHeld(in: event.flags)

    let consume: Bool
    switch type {
    case .keyDown:
      consume = handleKeyDown(event, modifierHeld: modifierHeld)
    case .flagsChanged:
      // Releasing the modifier commits the current selection.
      if isActive && !modifierHeld { deactivate(cancelled: false) }
      consume = false
    default:
      consume = false
    }

    return consume ? nil : Unmanaged.passUnretained(event)
  }

  private func modifierIsHeld(in flags: CGEventFlags) -> Bool {
    switch modifier {
    case .option: return flags.contains(.maskAlternate)
    case .command: return flags.contains(.maskCommand)
    }
  }

  /// Returns `true` when the key should be consumed (hidden from other apps).
  private func handleKeyDown(_ event: CGEvent, modifierHeld: Bool) -> Bool {
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

    // Consuming Tab+modifier is what suppresses the native ⌘Tab switcher.
    if keyCode == kVK_Tab && modifierHeld {
      handleTabPress(reverse: event.flags.contains(.maskShift))
      return true
    }

    guard isActive else { return false }

    switch keyCode {
    case kVK_Escape:
      deactivate(cancelled: true)
      return true
    case kVK_Return:
      deactivate(cancelled: false)
      return true
    case kVK_UpArrow, kVK_LeftArrow:
      onCyclePrev?()
      return true
    case kVK_DownArrow, kVK_RightArrow:
      onCycleNext?()
      return true
    default:
      return false
    }
  }

  // The first Tab press opens the switcher; each later press cycles the selection.
  private func handleTabPress(reverse: Bool) {
    guard isActive else {
      isActive = true
      onActivate?()
      return
    }
    if reverse {
      onCyclePrev?()
    } else {
      onCycleNext?()
    }
  }

  private func deactivate(cancelled: Bool) {
    guard isActive else { return }
    isActive = false
    if cancelled {
      onCancel?()
    } else {
      onRelease?()
    }
  }

  deinit {
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }

    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
  }
}

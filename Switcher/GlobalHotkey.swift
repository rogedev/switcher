import Carbon
import Cocoa

private func fourCharCode(_ string: String) -> FourCharCode {
  string.utf8.reduce(0 as FourCharCode) { ($0 << 8) + FourCharCode($1) }
}

private func hotkeyCallback(
  _ nextHandler: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event, let userData else { return OSStatus(eventNotHandledErr) }
  let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
  hotkey.handleHotKeyEvent(event)
  return noErr
}

class GlobalHotkey {
  typealias Handler = () -> Void

  var onActivate: Handler?
  var onCycleNext: Handler?
  var onCyclePrev: Handler?
  var onRelease: Handler?
  var onCancel: Handler?

  private var hotKeyRef: EventHotKeyRef?
  private var shiftHotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var globalFlagsMonitor: Any?
  private var localFlagsMonitor: Any?
  private var localKeyMonitor: Any?
  private(set) var isActive = false

  func register() {
    let sig = fourCharCode("ALTT")

    let hotKeyID = EventHotKeyID(signature: sig, id: 1)
    RegisterEventHotKey(
      UInt32(kVK_Tab),
      UInt32(optionKey),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    let shiftHotKeyID = EventHotKeyID(signature: sig, id: 2)
    RegisterEventHotKey(
      UInt32(kVK_Tab),
      UInt32(optionKey | shiftKey),
      shiftHotKeyID,
      GetApplicationEventTarget(),
      0,
      &shiftHotKeyRef
    )

    let selfPtr = Unmanaged.passUnretained(self).toOpaque()
    var eventSpecs = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    ]

    InstallEventHandler(
      GetApplicationEventTarget(),
      hotkeyCallback,
      eventSpecs.count,
      &eventSpecs,
      selfPtr,
      &eventHandlerRef
    )
  }

  func handleHotKeyEvent(_ event: EventRef) {
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )

    if !isActive {
      isActive = true
      startEventMonitoring()
      onActivate?()
    } else {
      if hotKeyID.id == 2 {
        onCyclePrev?()
      } else {
        onCycleNext?()
      }
    }
  }

  private func startEventMonitoring() {
    globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
      [weak self] event in
      self?.handleFlags(event)
    }

    localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
      [weak self] event in
      self?.handleFlags(event)
      return event
    }

    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, self.isActive else { return event }
      switch Int(event.keyCode) {
      case kVK_Escape:
        self.deactivate(cancelled: true)
        return nil
      case kVK_Return:
        self.deactivate(cancelled: false)
        return nil
      case kVK_UpArrow:
        self.onCyclePrev?()
        return nil
      case kVK_DownArrow, kVK_RightArrow:
        self.onCycleNext?()
        return nil
      case kVK_LeftArrow:
        self.onCyclePrev?()
        return nil
      default:
        return event
      }
    }
  }

  private func handleFlags(_ event: NSEvent) {
    guard isActive else { return }
    if !event.modifierFlags.contains(.option) {
      deactivate(cancelled: false)
    }
  }

  private func deactivate(cancelled: Bool) {
    guard isActive else { return }
    isActive = false
    stopEventMonitoring()
    if cancelled {
      onCancel?()
    } else {
      onRelease?()
    }
  }

  private func stopEventMonitoring() {
    if let m = globalFlagsMonitor {
      NSEvent.removeMonitor(m)
      globalFlagsMonitor = nil
    }
    if let m = localFlagsMonitor {
      NSEvent.removeMonitor(m)
      localFlagsMonitor = nil
    }
    if let m = localKeyMonitor {
      NSEvent.removeMonitor(m)
      localKeyMonitor = nil
    }
  }

  deinit {
    stopEventMonitoring()
    if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    if let ref = shiftHotKeyRef { UnregisterEventHotKey(ref) }
    if let ref = eventHandlerRef { RemoveEventHandler(ref) }
  }
}

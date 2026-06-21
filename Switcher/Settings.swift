import Foundation

enum HotkeyModifier: String {
  case option
  case command
}

enum DisplayMode: String {
  case icon
  case preview
}

enum Settings {
  private static let hotkeyModifierKey = "hotkeyModifier"
  private static let displayModeKey = "displayMode"

  static var hotkeyModifier: HotkeyModifier {
    get {
      let raw = UserDefaults.standard.string(forKey: hotkeyModifierKey) ?? ""
      return HotkeyModifier(rawValue: raw) ?? .option
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: hotkeyModifierKey) }
  }

  static var displayMode: DisplayMode {
    get {
      let raw = UserDefaults.standard.string(forKey: displayModeKey) ?? ""
      return DisplayMode(rawValue: raw) ?? .icon
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: displayModeKey) }
  }
}

import XCTest

@testable import Switcher

final class SettingsTests: XCTestCase {
  private let hotkeyModifierKey = "hotkeyModifier"
  private let displayModeKey = "displayMode"

  private var savedHotkeyModifier: Any?
  private var savedDisplayMode: Any?

  override func setUp() {
    super.setUp()
    // Preserve any real user values so tests don't clobber them.
    savedHotkeyModifier = UserDefaults.standard.object(forKey: hotkeyModifierKey)
    savedDisplayMode = UserDefaults.standard.object(forKey: displayModeKey)
    UserDefaults.standard.removeObject(forKey: hotkeyModifierKey)
    UserDefaults.standard.removeObject(forKey: displayModeKey)
  }

  override func tearDown() {
    UserDefaults.standard.set(savedHotkeyModifier, forKey: hotkeyModifierKey)
    UserDefaults.standard.set(savedDisplayMode, forKey: displayModeKey)
    super.tearDown()
  }

  func testHotkeyModifierDefaultsToOption() {
    XCTAssertEqual(Settings.hotkeyModifier, .option)
  }

  func testDisplayModeDefaultsToIcon() {
    XCTAssertEqual(Settings.displayMode, .icon)
  }

  func testHotkeyModifierRoundTrips() {
    Settings.hotkeyModifier = .command
    XCTAssertEqual(Settings.hotkeyModifier, .command)
    Settings.hotkeyModifier = .option
    XCTAssertEqual(Settings.hotkeyModifier, .option)
  }

  func testDisplayModeRoundTrips() {
    Settings.displayMode = .preview
    XCTAssertEqual(Settings.displayMode, .preview)
    Settings.displayMode = .icon
    XCTAssertEqual(Settings.displayMode, .icon)
  }

  func testHotkeyModifierFallsBackOnUnknownRawValue() {
    UserDefaults.standard.set("bogus", forKey: hotkeyModifierKey)
    XCTAssertEqual(Settings.hotkeyModifier, .option)
  }

  func testDisplayModeFallsBackOnUnknownRawValue() {
    UserDefaults.standard.set("bogus", forKey: displayModeKey)
    XCTAssertEqual(Settings.displayMode, .icon)
  }

  func testHotkeyModifierRawValueParsing() {
    XCTAssertEqual(HotkeyModifier(rawValue: "command"), .command)
    XCTAssertEqual(HotkeyModifier(rawValue: "option"), .option)
    XCTAssertNil(HotkeyModifier(rawValue: ""))
  }

  func testDisplayModeRawValueParsing() {
    XCTAssertEqual(DisplayMode(rawValue: "preview"), .preview)
    XCTAssertEqual(DisplayMode(rawValue: "icon"), .icon)
    XCTAssertNil(DisplayMode(rawValue: ""))
  }
}

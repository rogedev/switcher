import XCTest

@testable import Switcher

@MainActor
final class SwitcherViewTests: XCTestCase {
  private func makeWindow(id: CGWindowID, title: String) -> WindowInfo {
    WindowInfo(
      windowID: id,
      title: title,
      appName: "App \(id)",
      appIcon: nil,
      pid: pid_t(id),
      bounds: .zero,
      isMinimized: false,
      thumbnail: nil
    )
  }

  private func makeView(windowCount: Int) -> SwitcherView {
    let view = SwitcherView()
    let windows = (0..<windowCount).map { makeWindow(id: CGWindowID($0), title: "Window \($0)") }
    view.update(windows: windows, displayMode: .icon)
    return view
  }

  func testSelectedWindowIsNilWhenEmpty() {
    let view = makeView(windowCount: 0)
    XCTAssertNil(view.selectedWindow)
  }

  func testCycleForwardWrapsAround() {
    let view = makeView(windowCount: 3)
    view.selectIndex(0)
    XCTAssertEqual(view.selectedWindow?.windowID, 0)

    view.cycleSelection(forward: true)
    XCTAssertEqual(view.selectedWindow?.windowID, 1)
    view.cycleSelection(forward: true)
    XCTAssertEqual(view.selectedWindow?.windowID, 2)
    view.cycleSelection(forward: true)  // wraps back to start
    XCTAssertEqual(view.selectedWindow?.windowID, 0)
  }

  func testCycleBackwardWrapsAround() {
    let view = makeView(windowCount: 3)
    view.selectIndex(0)

    view.cycleSelection(forward: false)  // wraps to last
    XCTAssertEqual(view.selectedWindow?.windowID, 2)
    view.cycleSelection(forward: false)
    XCTAssertEqual(view.selectedWindow?.windowID, 1)
  }

  func testSelectIndexClampsAboveRange() {
    let view = makeView(windowCount: 3)
    view.selectIndex(99)
    XCTAssertEqual(view.selectedWindow?.windowID, 2)
  }

  func testSelectIndexClampsBelowRange() {
    let view = makeView(windowCount: 3)
    view.selectIndex(-5)
    XCTAssertEqual(view.selectedWindow?.windowID, 0)
  }

  func testCycleOnEmptyListIsNoOp() {
    let view = makeView(windowCount: 0)
    view.cycleSelection(forward: true)
    view.cycleSelection(forward: false)
    XCTAssertNil(view.selectedWindow)
  }
}

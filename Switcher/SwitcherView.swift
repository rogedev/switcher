import Carbon.HIToolbox
import Cocoa

class SwitcherView: NSView {
  var onSelect: ((WindowInfo) -> Void)?

  private var effectView: NSVisualEffectView!
  private var tileViews: [WindowTileView] = []
  private var windows: [WindowInfo] = []
  private var selectedIndex = 0

  private let tileWidth: CGFloat = 220
  private let tileHeight: CGFloat = 172
  private let tileGap: CGFloat = 10
  private let panelPadding: CGFloat = 20
  private let cornerRadius: CGFloat = 12

  var selectedWindow: WindowInfo? {
    guard selectedIndex >= 0, selectedIndex < windows.count else { return nil }
    return windows[selectedIndex]
  }

  override init(frame: NSRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    wantsLayer = true

    effectView = NSVisualEffectView()
    effectView.material = .hudWindow
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    effectView.wantsLayer = true
    effectView.layer?.cornerRadius = cornerRadius
    effectView.layer?.masksToBounds = true
    addSubview(effectView)
  }

  override var acceptsFirstResponder: Bool { true }

  func update(windows: [WindowInfo]) {
    self.windows = windows
    tileViews.forEach { $0.removeFromSuperview() }
    tileViews = windows.map { window in
      let tile = WindowTileView(windowInfo: window)
      tile.onClick = { [weak self] in
        guard let self else { return }
        if let idx = self.tileViews.firstIndex(of: tile) {
          self.selectIndex(idx)
          self.onSelect?(self.windows[idx])
        }
      }
      effectView.addSubview(tile)
      return tile
    }
    needsLayout = true
  }

  func idealSize(for screen: NSScreen) -> NSSize {
    let count = windows.count
    guard count > 0 else { return NSSize(width: 300, height: 200) }

    let maxWidth = screen.frame.width * 0.8
    let maxCols = max(1, Int((maxWidth - 2 * panelPadding + tileGap) / (tileWidth + tileGap)))
    let cols = min(count, maxCols)
    let rows = Int(ceil(Double(count) / Double(cols)))

    let width = CGFloat(cols) * tileWidth + CGFloat(max(0, cols - 1)) * tileGap + 2 * panelPadding
    let height = CGFloat(rows) * tileHeight + CGFloat(max(0, rows - 1)) * tileGap + 2 * panelPadding

    return NSSize(width: width, height: height)
  }

  override func layout() {
    super.layout()
    effectView.frame = bounds

    let count = tileViews.count
    guard count > 0 else { return }

    let availableWidth = bounds.width - 2 * panelPadding
    let cols = max(1, Int((availableWidth + tileGap) / (tileWidth + tileGap)))

    for (i, tile) in tileViews.enumerated() {
      let col = i % cols
      let row = i / cols
      let x = panelPadding + CGFloat(col) * (tileWidth + tileGap)
      let y = bounds.height - panelPadding - CGFloat(row + 1) * tileHeight - CGFloat(row) * tileGap
      tile.frame = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }
  }

  func updateThumbnail(at index: Int, image: NSImage) {
    guard index < tileViews.count else { return }
    tileViews[index].setThumbnail(image)
  }

  func selectIndex(_ index: Int) {
    guard !windows.isEmpty else { return }
    let clamped = max(0, min(index, windows.count - 1))
    tileViews[safe: selectedIndex]?.isSelected = false
    selectedIndex = clamped
    tileViews[safe: selectedIndex]?.isSelected = true
  }

  func cycleSelection(forward: Bool) {
    guard !windows.isEmpty else { return }
    let next: Int
    if forward {
      next = (selectedIndex + 1) % windows.count
    } else {
      next = (selectedIndex - 1 + windows.count) % windows.count
    }
    selectIndex(next)
  }

  override func keyDown(with event: NSEvent) {
    switch Int(event.keyCode) {
    case kVK_Escape:
      return
    case kVK_Return:
      if let window = selectedWindow {
        onSelect?(window)
      }
    case kVK_LeftArrow, kVK_UpArrow:
      cycleSelection(forward: false)
    case kVK_RightArrow, kVK_DownArrow:
      cycleSelection(forward: true)
    default:
      super.keyDown(with: event)
    }
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

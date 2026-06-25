import Carbon.HIToolbox
import Cocoa

class SwitcherView: NSView {
  var onSelect: ((WindowInfo) -> Void)?

  private var effectView: NSVisualEffectView!
  private var tileViews: [WindowTileView] = []
  private var windows: [WindowInfo] = []
  private var selectedIndex = 0
  private var displayMode: DisplayMode = .preview
  private var tileWidth: CGFloat { displayMode == .icon ? 132 : 220 }
  private var tileHeight: CGFloat { displayMode == .icon ? 132 : 172 }
  private var tileGap: CGFloat { displayMode == .icon ? 4 : 10 }
  private var panelPadding: CGFloat { displayMode == .icon ? 24 : 20 }
  private var panelCornerRadius: CGFloat { displayMode == .icon ? 28 : 12 }
  private let iconTitleHeight: CGFloat = 30
  private let previewThumbHeight: CGFloat = 130
  private let previewInnerPadding: CGFloat = 8
  private let previewMinTileWidth: CGFloat = 90
  private let previewMaxTileWidth: CGFloat = 340
  private let selectionTitleLabel = NSTextField(labelWithString: "")

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
    effectView.layer?.cornerRadius = panelCornerRadius
    effectView.layer?.cornerCurve = .continuous
    effectView.layer?.borderWidth = 1
    effectView.layer?.borderColor = NSColor(white: 1, alpha: 0.16).cgColor
    effectView.layer?.masksToBounds = true
    addSubview(effectView)

    selectionTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    selectionTitleLabel.textColor = .labelColor
    selectionTitleLabel.alignment = .center
    selectionTitleLabel.lineBreakMode = .byTruncatingTail
    selectionTitleLabel.maximumNumberOfLines = 1
    selectionTitleLabel.cell?.truncatesLastVisibleLine = true
    selectionTitleLabel.isBezeled = false
    selectionTitleLabel.isEditable = false
    selectionTitleLabel.drawsBackground = false
    selectionTitleLabel.isHidden = true
    effectView.addSubview(selectionTitleLabel)
  }

  override var acceptsFirstResponder: Bool { true }

  func update(windows: [WindowInfo], displayMode: DisplayMode) {
    self.windows = windows
    self.displayMode = displayMode
    effectView.layer?.cornerRadius = panelCornerRadius
    tileViews.forEach { $0.removeFromSuperview() }
    tileViews = windows.map { window in
      let tile = WindowTileView(windowInfo: window, displayMode: displayMode)
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
    selectionTitleLabel.isHidden = displayMode != .icon
    needsLayout = true
  }

  private func previewTileWidth(at index: Int) -> CGFloat {
    let raw = previewThumbHeight * windows[index].aspectRatio + 2 * previewInnerPadding
    return min(max(raw, previewMinTileWidth), previewMaxTileWidth)
  }

  private func packPreviewRows(maxContentWidth: CGFloat) -> [[Int]] {
    var rows: [[Int]] = []
    var current: [Int] = []
    var currentWidth: CGFloat = 0

    for i in windows.indices {
      let w = previewTileWidth(at: i)
      let projected = current.isEmpty ? w : currentWidth + tileGap + w

      if !current.isEmpty && projected > maxContentWidth {
        rows.append(current)
        current = [i]
        currentWidth = w

      } else {
        current.append(i)
        currentWidth = projected
      }
    }
    if !current.isEmpty { rows.append(current) }
    return rows
  }

  private func rowWidth(_ row: [Int]) -> CGFloat {
    let tiles = row.reduce(CGFloat(0)) { $0 + previewTileWidth(at: $1) }
    return tiles + CGFloat(max(0, row.count - 1)) * tileGap
  }

  func idealSize(for screen: NSScreen) -> NSSize {
    let count = windows.count
    guard count > 0 else { return NSSize(width: 300, height: 200) }

    let maxWidth = screen.frame.width * 0.8

    if displayMode != .icon {
      let rows = packPreviewRows(maxContentWidth: maxWidth - 2 * panelPadding)
      let widest = rows.map(rowWidth).max() ?? 0
      let width = widest + 2 * panelPadding
      let height =
        CGFloat(rows.count) * tileHeight + CGFloat(max(0, rows.count - 1)) * tileGap
        + 2 * panelPadding
      return NSSize(width: width, height: height)
    }

    let maxCols = max(1, Int((maxWidth - 2 * panelPadding + tileGap) / (tileWidth + tileGap)))
    let cols = min(count, maxCols)
    let rows = Int(ceil(Double(count) / Double(cols)))

    let width = CGFloat(cols) * tileWidth + CGFloat(max(0, cols - 1)) * tileGap + 2 * panelPadding
    let height =
      CGFloat(rows) * tileHeight + CGFloat(max(0, rows - 1)) * tileGap + 2 * panelPadding
      + iconTitleHeight

    return NSSize(width: width, height: height)
  }

  override func layout() {
    super.layout()
    effectView.frame = bounds

    let count = tileViews.count
    guard count > 0 else { return }

    if displayMode != .icon {
      layoutPreviewTiles()
      return
    }

    let availableWidth = bounds.width - 2 * panelPadding
    let cols = max(1, Int((availableWidth + tileGap) / (tileWidth + tileGap)))

    for (i, tile) in tileViews.enumerated() {
      let col = i % cols
      let row = i / cols
      let x = panelPadding + CGFloat(col) * (tileWidth + tileGap)
      let y = bounds.height - panelPadding - CGFloat(row + 1) * tileHeight - CGFloat(row) * tileGap
      tile.frame = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }

    if displayMode == .icon {
      selectionTitleLabel.frame = NSRect(
        x: panelPadding,
        y: panelPadding / 2,
        width: bounds.width - 2 * panelPadding,
        height: iconTitleHeight
      )
    }
  }

  private func layoutPreviewTiles() {
    let maxContentWidth = bounds.width - 2 * panelPadding
    let rows = packPreviewRows(maxContentWidth: maxContentWidth)

    for (rowIdx, row) in rows.enumerated() {
      let width = rowWidth(row)
      var x = panelPadding + (maxContentWidth - width) / 2
      let y =
        bounds.height - panelPadding - CGFloat(rowIdx + 1) * tileHeight
        - CGFloat(rowIdx) * tileGap

      for tileIndex in row {
        let w = previewTileWidth(at: tileIndex)
        tileViews[tileIndex].frame = NSRect(x: x, y: y, width: w, height: tileHeight)
        x += w + tileGap
      }
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
    if displayMode == .icon {
      selectionTitleLabel.stringValue = windows[selectedIndex].title
    }
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

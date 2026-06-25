import Cocoa

class WindowTileView: NSView {
  var onClick: (() -> Void)?

  var isSelected: Bool = false {
    didSet { updateAppearance() }
  }

  private let displayMode: DisplayMode
  private let thumbnailView = NSImageView()
  private let largeIconView = NSImageView()
  private let iconView = NSImageView()
  private let titleLabel = NSTextField(labelWithString: "")
  private let highlightBorder = CALayer()
  private let selectionLayer = CALayer()

  private let thumbnailHeight: CGFloat = 130
  private let iconSize: CGFloat = 20
  private let innerPadding: CGFloat = 8
  private let iconModeInset: CGFloat = 4
  private let selectionInset: CGFloat = 10

  init(windowInfo: WindowInfo, displayMode: DisplayMode) {
    self.displayMode = displayMode
    super.init(frame: .zero)
    setup(windowInfo: windowInfo)
  }

  required init?(coder: NSCoder) {
    self.displayMode = .preview
    super.init(coder: coder)
  }

  private func setup(windowInfo: WindowInfo) {
    wantsLayer = true
    let radius: CGFloat = displayMode == .icon ? 12 : 8
    layer?.cornerRadius = radius

    highlightBorder.borderColor = NSColor.controlAccentColor.cgColor
    highlightBorder.borderWidth = 0
    highlightBorder.cornerRadius = radius

    if displayMode == .icon {
      setupIconMode(windowInfo: windowInfo)
    } else {
      setupPreviewMode(windowInfo: windowInfo)
    }

    layer?.addSublayer(highlightBorder)

    let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
    addGestureRecognizer(clickGesture)

    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
  }

  private func setupIconMode(windowInfo: WindowInfo) {
    selectionLayer.backgroundColor = NSColor.clear.cgColor
    selectionLayer.cornerCurve = .continuous
    layer?.addSublayer(selectionLayer)

    largeIconView.image = windowInfo.appIcon
    largeIconView.imageScaling = .scaleProportionallyUpOrDown
    largeIconView.imageAlignment = .alignCenter
    addSubview(largeIconView)
  }

  private func setupPreviewMode(windowInfo: WindowInfo) {
    thumbnailView.imageScaling = .scaleProportionallyUpOrDown
    thumbnailView.imageAlignment = .alignCenter
    thumbnailView.wantsLayer = true
    thumbnailView.layer?.cornerRadius = 6
    thumbnailView.layer?.masksToBounds = true
    addSubview(thumbnailView)

    if let thumbnail = windowInfo.thumbnail {
      thumbnailView.image = thumbnail
      largeIconView.isHidden = true
      thumbnailView.layer?.backgroundColor = NSColor.clear.cgColor
    } else {
      thumbnailView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.8).cgColor
      largeIconView.image = windowInfo.appIcon
      largeIconView.imageScaling = .scaleProportionallyUpOrDown
      largeIconView.imageAlignment = .alignCenter
      addSubview(largeIconView)
    }

    iconView.imageScaling = .scaleProportionallyDown
    iconView.image = windowInfo.appIcon
    addSubview(iconView)

    titleLabel.stringValue = windowInfo.title
    titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
    titleLabel.textColor = .labelColor
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.maximumNumberOfLines = 1
    titleLabel.cell?.truncatesLastVisibleLine = true
    titleLabel.isBezeled = false
    titleLabel.isEditable = false
    titleLabel.drawsBackground = false
    addSubview(titleLabel)
  }

  func setThumbnail(_ image: NSImage) {
    thumbnailView.image = image
    largeIconView.isHidden = true
  }

  override func layout() {
    super.layout()

    if displayMode == .icon {
      layoutIconMode()
    } else {
      layoutPreviewMode()
    }

    highlightBorder.frame = bounds
  }

  private func layoutIconMode() {
    let side = min(bounds.width, bounds.height) - 2 * iconModeInset
    largeIconView.frame = NSRect(
      x: (bounds.width - side) / 2,
      y: (bounds.height - side) / 2,
      width: side,
      height: side
    )

    let sel = bounds.insetBy(dx: selectionInset, dy: selectionInset)
    selectionLayer.frame = sel
    selectionLayer.cornerRadius = sel.width * 0.2237
  }

  private func layoutPreviewMode() {
    let thumbY = bounds.height - innerPadding - thumbnailHeight
    thumbnailView.frame = NSRect(
      x: innerPadding,
      y: thumbY,
      width: bounds.width - 2 * innerPadding,
      height: thumbnailHeight
    )

    if !largeIconView.isHidden {
      let iconSz: CGFloat = 64
      largeIconView.frame = NSRect(
        x: (bounds.width - iconSz) / 2,
        y: thumbY + (thumbnailHeight - iconSz) / 2,
        width: iconSz,
        height: iconSz
      )
    }

    let titleY: CGFloat = 6
    let iconX: CGFloat = innerPadding + 2
    iconView.frame = NSRect(x: iconX, y: titleY + 2, width: iconSize, height: iconSize)

    let titleX = iconX + iconSize + 6
    titleLabel.frame = NSRect(
      x: titleX,
      y: titleY + 2,
      width: bounds.width - titleX - innerPadding,
      height: 18
    )
  }

  private func updateAppearance() {
    if displayMode == .icon {
      selectionLayer.backgroundColor =
        isSelected ? NSColor(white: 1, alpha: 0.22).cgColor : NSColor.clear.cgColor
      return
    }

    if isSelected {
      highlightBorder.borderWidth = 2.5
      layer?.backgroundColor = NSColor(white: 1, alpha: 0.1).cgColor
    } else {
      highlightBorder.borderWidth = 0
      layer?.backgroundColor = NSColor.clear.cgColor
    }
  }

  @objc private func handleClick() {
    onClick?()
  }

  override func mouseEntered(with event: NSEvent) {
    guard !isSelected else { return }
    if displayMode == .icon {
      selectionLayer.backgroundColor = NSColor(white: 1, alpha: 0.10).cgColor
    } else {
      layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
    }
  }

  override func mouseExited(with event: NSEvent) {
    guard !isSelected else { return }
    if displayMode == .icon {
      selectionLayer.backgroundColor = NSColor.clear.cgColor
    } else {
      layer?.backgroundColor = NSColor.clear.cgColor
    }
  }
}

extension WindowTileView {
  static func == (lhs: WindowTileView, rhs: WindowTileView) -> Bool {
    lhs === rhs
  }
}

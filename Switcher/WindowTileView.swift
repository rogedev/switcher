import Cocoa

class WindowTileView: NSView {
  var onClick: (() -> Void)?

  var isSelected: Bool = false {
    didSet { updateAppearance() }
  }

  private let thumbnailView = NSImageView()
  private let largeIconView = NSImageView()
  private let iconView = NSImageView()
  private let titleLabel = NSTextField(labelWithString: "")
  private let appNameLabel = NSTextField(labelWithString: "")
  private let highlightBorder = CALayer()

  private let thumbnailHeight: CGFloat = 130
  private let iconSize: CGFloat = 20
  private let innerPadding: CGFloat = 8

  init(windowInfo: WindowInfo) {
    super.init(frame: .zero)
    setup(windowInfo: windowInfo)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  private func setup(windowInfo: WindowInfo) {
    wantsLayer = true
    layer?.cornerRadius = 8

    thumbnailView.imageScaling = .scaleProportionallyUpOrDown
    thumbnailView.imageAlignment = .alignCenter
    thumbnailView.wantsLayer = true
    thumbnailView.layer?.cornerRadius = 6
    thumbnailView.layer?.masksToBounds = true
    thumbnailView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.8).cgColor
    addSubview(thumbnailView)

    if let thumbnail = windowInfo.thumbnail {
      thumbnailView.image = thumbnail
      largeIconView.isHidden = true
    } else {
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

    highlightBorder.borderColor = NSColor.controlAccentColor.cgColor
    highlightBorder.borderWidth = 0
    highlightBorder.cornerRadius = 8
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

  func setThumbnail(_ image: NSImage) {
    thumbnailView.image = image
    largeIconView.isHidden = true
  }

  override func layout() {
    super.layout()

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

    highlightBorder.frame = bounds
  }

  private func updateAppearance() {
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
    if !isSelected {
      layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
    }
  }

  override func mouseExited(with event: NSEvent) {
    if !isSelected {
      layer?.backgroundColor = NSColor.clear.cgColor
    }
  }
}

extension WindowTileView {
  static func == (lhs: WindowTileView, rhs: WindowTileView) -> Bool {
    lhs === rhs
  }
}

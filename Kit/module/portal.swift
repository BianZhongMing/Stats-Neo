//
//  portal.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public enum CombinedAppearance: String, CaseIterable {
    case system
    case light
    case dark

    public var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

public enum CombinedPortalStyle {
    public static let contentWidth: CGFloat = 320
    public static let panelWidth: CGFloat = 336
    public static let horizontalInset: CGFloat = 12
    public static let verticalInset: CGFloat = 8

    public static func surface(_ view: NSView, radius: CGFloat = 8) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(isDarkMode ? 0.045 : 0.025).cgColor
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(isDarkMode ? 0.24 : 0.14).cgColor
    }
}

public func combinedDataRow(_ stack: NSStackView, title: String, value: String = "", color: NSColor? = nil, selectable: Bool = false) -> ValueField {
    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 6

    if let color {
        let marker = ColorBlock(color: color)
        marker.layer?.cornerRadius = 5
        row.addArrangedSubview(marker)
    }

    let label = LabelField(title)
    label.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
    label.textColor = .secondaryLabelColor
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let output = ValueField(value)
    output.isSelectable = selectable
    output.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
    output.alignment = .right
    output.setContentCompressionResistancePriority(.required, for: .horizontal)

    row.addArrangedSubview(label)
    row.addArrangedSubview(NSView())
    row.addArrangedSubview(output)
    stack.addArrangedSubview(row)
    row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    return output
}

public func combinedMetricStack(spacing: CGFloat = 4) -> NSStackView {
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.distribution = .fillEqually
    stack.spacing = spacing
    return stack
}

public final class CombinedPortalSeparator: NSStackView {
    private let line = NSView()
    public override var wantsUpdateLayer: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.orientation = .horizontal
        self.edgeInsets = NSEdgeInsets(top: 0, left: CombinedPortalStyle.horizontalInset, bottom: 0, right: CombinedPortalStyle.horizontalInset)
        self.line.wantsLayer = true
        self.addArrangedSubview(self.line)
        self.line.heightAnchor.constraint(equalToConstant: 1).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func updateLayer() {
        self.line.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(isDarkMode ? 0.34 : 0.22).cgColor
    }
}

public final class CombinedCoreBarsView: NSView {
    private var values: [ColorValue] = []

    public override var isFlipped: Bool { false }

    public func setValues(_ values: [ColorValue]) {
        self.values = values
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !self.values.isEmpty else { return }
        let inset: CGFloat = 6
        let spacing: CGFloat = 3
        let usableWidth = max(0, self.bounds.width - inset*2)
        let barWidth = max(2, (usableWidth - spacing*CGFloat(self.values.count-1)) / CGFloat(self.values.count))
        let baseline: CGFloat = 5
        let maxHeight = max(1, self.bounds.height - baseline - 6)
        for (index, item) in self.values.enumerated() {
            let height = max(2, min(maxHeight, CGFloat(item.value) * maxHeight))
            let rect = NSRect(x: inset + CGFloat(index)*(barWidth+spacing), y: baseline, width: barWidth, height: height)
            (item.color ?? .controlAccentColor).setFill()
            NSBezierPath(rect: rect).fill()
        }
    }
}

public final class CombinedHistoryBarsView: NSView {
    private var points: [(Double, Double)]
    private let firstColor: NSColor
    private let secondColor: NSColor
    private let stacked: Bool
    private let fixedMaximum: Double?

    public init(
        count: Int = 18,
        firstColor: NSColor,
        secondColor: NSColor,
        stacked: Bool = false,
        fixedMaximum: Double? = nil
    ) {
        self.points = Array(repeating: (0, 0), count: max(2, count))
        self.firstColor = firstColor
        self.secondColor = secondColor
        self.stacked = stacked
        self.fixedMaximum = fixedMaximum
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 7
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(isDarkMode ? 0.045 : 0.025).cgColor
    }

    public func addValue(first: Double, second: Double) {
        self.points.removeFirst()
        self.points.append((max(0, first), max(0, second)))
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let inset: CGFloat = 7
        let gap: CGFloat = 2
        let observedMaximum = self.points.map { self.stacked ? $0.0 + $0.1 : max($0.0, $0.1) }.max() ?? 1
        let maxValue = max(1, self.fixedMaximum ?? observedMaximum)
        let usableWidth = max(0, self.bounds.width - inset*2)
        let groupWidth = usableWidth / CGFloat(self.points.count)
        let barWidth = self.stacked ? max(1, groupWidth-gap) : max(1, (groupWidth-gap)/2)
        let maxHeight = max(1, self.bounds.height - inset*2)
        for (index, point) in self.points.enumerated() {
            let x = inset + CGFloat(index)*groupWidth
            let firstHeight = max(1, CGFloat(point.0/maxValue)*maxHeight)
            let secondHeight = max(1, CGFloat(point.1/maxValue)*maxHeight)
            self.firstColor.setFill()
            NSBezierPath(rect: NSRect(x: x, y: inset, width: barWidth, height: firstHeight)).fill()
            self.secondColor.setFill()
            let secondX = self.stacked ? x : x+barWidth+gap
            let secondY = self.stacked ? inset+firstHeight : inset
            NSBezierPath(rect: NSRect(x: secondX, y: secondY, width: barWidth, height: secondHeight)).fill()
        }
    }
}

public protocol Portal_p: NSView {
    var name: String { get }
    var height: CGFloat { get }
}

open class PortalWrapper: NSStackView, Portal_p {
    public var name: String
    public var height: CGFloat
    
    private let header: PortalHeader
    public let body: NSStackView
    
    public init(_ type: ModuleType, height: CGFloat = 100) {
        self.name = type.stringValue
        self.height = 28 + height

        self.header = PortalHeader(type.stringValue)
        self.body = {
            let view = NSStackView()
            view.orientation = .horizontal
            view.distribution = .fill
            view.alignment = .centerY
            view.spacing = 12
            view.edgeInsets = NSEdgeInsets(
                top: CombinedPortalStyle.verticalInset,
                left: CombinedPortalStyle.horizontalInset,
                bottom: CombinedPortalStyle.verticalInset,
                right: CombinedPortalStyle.horizontalInset
            )
            return view
        }()
        
        super.init(frame: .zero)
        
        self.orientation = .vertical
        self.alignment = .width
        self.spacing = 0
        
        self.addArrangedSubview(self.header)
        self.addArrangedSubview(self.body)
        
        self.load()
        
        if self.body.subviews.isEmpty {
            self.body.addArrangedSubview(NSView())
        }
        
        self.heightAnchor.constraint(equalToConstant: self.height).isActive = true
        self.body.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }

    open override func updateLayer() {
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.borderWidth = 0
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func load() {
        self.body.addArrangedSubview(NSView())
    }
}

public class PortalHeader: NSStackView {
    private let name: String
    
    public init(_ name: String) {
        self.name = name
        
        super.init(frame: NSRect.zero)
        self.heightAnchor.constraint(equalToConstant: 28).isActive = true
        self.edgeInsets = NSEdgeInsets(top: 5, left: CombinedPortalStyle.horizontalInset, bottom: 3, right: CombinedPortalStyle.horizontalInset)

        let title = NSTextField()
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .controlAccentColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .natural
        title.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        title.stringValue = localizedString(name)

        let settings = NSButton()
        settings.heightAnchor.constraint(equalToConstant: 16).isActive = true
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleProportionallyDown
        settings.image = iconFromSymbol(name: "gearshape", scale: .small)
        settings.contentTintColor = .tertiaryLabelColor
        settings.isBordered = false
        settings.action = #selector(self.openSettings)
        settings.target = self
        settings.toolTip = localizedString("Open module settings")
        settings.focusRingType = .none
        
        self.addArrangedSubview(title)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(settings)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func openSettings() {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.name])
    }
}

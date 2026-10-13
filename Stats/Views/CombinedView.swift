//
//  CombinedView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09/01/2023
//  Using Swift 5.0
//  Running on macOS 13.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class CombinedView: NSObject, NSGestureRecognizerDelegate {
    private var menuBarItem: NSStatusItem? = nil
    private var view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height))
    private let networkSpeedView = SpeedWidget(title: "Network", config: nil)
    private var popup: PopupWindow? = nil

    private var status: Bool {
        Store.shared.bool(key: "CombinedModules", defaultValue: false)
    }
    // When true the menu bar item shows the Network module's speed widgets (same as the standalone Network item);
    // when false it only shows a single combined icon.
    private var showNetwork: Bool {
        Store.shared.bool(key: "CombinedModules_network", defaultValue: false)
    }

    override init() {
        super.init()

        self.networkSpeedView.widthHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.updateNetworkSpeedWidth()
            }
        }

        modules.forEach { (m: Module) in
            m.menuBar.callback = { [weak self] in
                if let s = self?.status, s {
                    DispatchQueue.main.async(execute: {
                        self?.recalculate()
                    })
                }
            }
        }

        self.popup = PopupWindow(title: "Stats", module: .combined, view: Popup()) { _ in }

        if self.status {
            self.enable()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(listenForOneView), name: .toggleOneView, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleRearrrange), name: .moduleRearrange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateNetworkSpeed), name: .combinedNetworkSpeed, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func enable() {
        self.menuBarItem = NSStatusBar.system.statusItem(withLength: 0)
        DispatchQueue.main.async(execute: {
            self.menuBarItem?.autosaveName = "CombinedModules"
        })
        self.menuBarItem?.button?.addSubview(self.view)
        self.menuBarItem?.button?.image = NSImage()
        self.menuBarItem?.button?.toolTip = localizedString("Combined modules")

        self.menuBarItem?.button?.target = self
        self.menuBarItem?.button?.action = #selector(self.handleClick)
        self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])

        DispatchQueue.main.async(execute: {
            self.recalculate()
        })
    }

    public func disable() {
        if let item = self.menuBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        self.menuBarItem = nil
    }

    private func recalculate() {
        guard self.status, self.menuBarItem != nil else { return }
        self.view.subviews.forEach({ $0.removeFromSuperview() })

        // Network-speed mode owns an independent SpeedWidget. Never move the Network module's
        // menu-bar view into this status item: doing so collapses its dynamic width when the
        // standalone Network item is disabled and leaves only the arrow column visible.
        if self.showNetwork {
            self.view.addSubview(self.networkSpeedView)
            self.networkSpeedView.setFrameOrigin(NSPoint(x: 0, y: 0))
            self.networkSpeedView.needsDisplay = true
            self.updateNetworkSpeedWidth()
            return
        }

        // Default: show a single combined icon.
        self.view.addSubview(AppIcon())
        self.view.setFrameSize(NSSize(width: AppIcon.size.width, height: self.view.frame.height))
        self.menuBarItem?.length = AppIcon.size.width
    }

    private func updateNetworkSpeedWidth() {
        guard self.showNetwork, self.menuBarItem != nil else { return }
        let width = max(self.networkSpeedView.frame.width, 58)
        self.view.setFrameSize(NSSize(width: width, height: Constants.Widget.height))
        self.menuBarItem?.length = width
    }

    @objc private func updateNetworkSpeed(_ notification: Notification) {
        guard let download = notification.userInfo?["download"] as? Int64,
              let upload = notification.userInfo?["upload"] as? Int64 else { return }
        self.networkSpeedView.setValue(input: download, output: upload)
    }

    // call when popup appear/disappear
    private func visibilityCallback(_ state: Bool) {}

    @objc private func handleClick() {
        // The combined item always opens the aggregated popup, regardless of whether it shows an icon or network speed.
        self.togglePopup()
    }

    private func togglePopup() {
        guard let popup = self.popup, let item = self.menuBarItem, let window = item.button?.window else { return }
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }

        if popup.occlusionState.rawValue == 8192 {
            NSApplication.shared.activate(ignoringOtherApps: true)

            popup.contentView?.invalidateIntrinsicContentSize()

            let windowCenter = popup.contentView!.intrinsicContentSize.width / 2
            var x = window.frame.origin.x - windowCenter + window.frame.width/2
            let y = window.frame.origin.y - popup.contentView!.intrinsicContentSize.height - 3

            let buttonPoint = NSPoint(x: window.frame.midX, y: window.frame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonPoint) }) ?? NSScreen.main {
                if x + popup.contentView!.intrinsicContentSize.width > screen.frame.maxX {
                    x = screen.frame.maxX - popup.contentView!.intrinsicContentSize.width - 3
                }
                if x < screen.frame.minX {
                    x = screen.frame.minX + 3
                }
            }

            popup.setFrameOrigin(NSPoint(x: x, y: y))
            popup.setIsVisible(true)
        } else {
            popup.setIsVisible(false)
        }
    }

    @objc private func listenForOneView(_ notification: Notification) {
        guard notification.userInfo?["module"] == nil else { return }

        if self.status {
            self.enable()
        } else {
            self.disable()
        }
    }

    @objc private func listenForModuleRearrrange() {
        self.recalculate()
    }
}

private class Popup: NSStackView, Popup_p {
    fileprivate var keyboardShortcut: [UInt16] = []
    fileprivate var sizeCallback: ((NSSize) -> Void)? = nil

    init() {
        self.keyboardShortcut = Store.shared.array(key: "CombinedModules_popup_keyboardShortcut", defaultValue: []) as? [UInt16] ?? []

        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))

        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .width
        self.spacing = Constants.Popup.spacing

        self.reinit()

        NotificationCenter.default.addObserver(self, selector: #selector(reinit), name: .toggleModule, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reinit), name: .moduleRearrange, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
    }

    fileprivate func settings() -> NSView? { return nil }
    fileprivate func appear() {}
    fileprivate func disappear() {}
    fileprivate func setKeyboardShortcut(_ binding: [UInt16]) {
        self.keyboardShortcut = binding
        Store.shared.set(key: "CombinedModules_popup_keyboardShortcut", value: binding)
    }

    @objc private func reinit() {
        self.subviews.forEach({ $0.removeFromSuperview() })

        let availableModules = modules.filter({ $0.combinedPanelActive }).sorted(by: { $0.combinedPosition < $1.combinedPosition })
        var modulesHeight: CGFloat = 0
        availableModules.forEach { (m: Module) in
            if let p = m.portal {
                modulesHeight += p.height
                self.addArrangedSubview(p)
                // NSStackView `.width` alignment is unreliable on the current SDK. Explicitly
                // pin every portal to the Combined panel width so narrower scrollable content
                // (notably Sensors) cannot center the whole portal and indent its header.
                p.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
            }
        }

        let h = max(0, modulesHeight + (CGFloat(availableModules.count - 1) * self.spacing))
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.sizeCallback?(self.frame.size)
    }
}

// MARK: - Combined settings (standalone page)

internal class CombinedSettings: NSStackView {
    internal var enabled: Bool {
        Store.shared.bool(key: "CombinedModules", defaultValue: false)
    }
    private var state: Bool {
        get { self.enabled }
        set { Store.shared.set(key: "CombinedModules", value: newValue) }
    }
    private var showNetwork: Bool {
        get { Store.shared.bool(key: "CombinedModules_network", defaultValue: false) }
        set { Store.shared.set(key: "CombinedModules_network", value: newValue) }
    }

    private var optionsSection: PreferencesSection?
    private var listSection: PreferencesSection?
    private let moduleList = CombinedModuleListView()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = ScrollableStackView(orientation: .vertical)
        scrollView.stackView.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        scrollView.stackView.spacing = Constants.Settings.margin

        scrollView.stackView.addArrangedSubview(self.headerView())

        self.optionsSection = PreferencesSection([
            PreferencesRow(localizedString("Show network speed"), component: switchView(
                action: #selector(self.toggleNetwork),
                state: self.showNetwork
            ))
        ])
        scrollView.stackView.addArrangedSubview(self.optionsSection!)

        self.listSection = PreferencesSection(title: localizedString("Components"))
        self.listSection!.add(self.moduleList)
        scrollView.stackView.addArrangedSubview(self.listSection!)
        // NOTE: NSStackView.alignment = .width is rejected on this SDK (it collapses to
        // .notAnAttribute). Pin explicit widths instead so the card and the list fill the
        // scroll content width and every row shares one aligned column grid.
        let m = Constants.Settings.margin
        self.listSection!.widthAnchor.constraint(equalTo: scrollView.stackView.widthAnchor, constant: -2 * m).isActive = true
        // The card container insets by one margin on each side; the module list sits inside it.
        self.moduleList.widthAnchor.constraint(equalTo: self.listSection!.widthAnchor, constant: -2 * m).isActive = true

        self.addArrangedSubview(scrollView)

        self.updateVisibility()

        NotificationCenter.default.addObserver(self, selector: #selector(self.reload), name: .toggleModule, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleModule, object: nil)
    }

    private func headerView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.alignment = .leading
        view.spacing = 3
        view.edgeInsets = NSEdgeInsets(top: 10, left: 4, bottom: 6, right: 4)

        let title = NSTextField(labelWithString: localizedString("Combined modules"))
        title.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        title.textColor = .labelColor

        let subtitle = NSTextField(labelWithString: localizedString("Combined page subtitle"))
        subtitle.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.preferredMaxLayoutWidth = Constants.Settings.width - 60

        view.addArrangedSubview(title)
        view.addArrangedSubview(subtitle)
        return view
    }

    fileprivate func updateVisibility() {
        self.moduleList.setEnabled(self.state)
        self.listSection?.subviews.forEach { $0.alphaValue = self.state ? 1.0 : 0.45 }
    }

    func viewWillAppear() {
        self.moduleList.reload()
    }

    internal func setEnabled(_ enabled: Bool) {
        self.state = enabled
        modules.forEach { $0.syncCombinedState() }
        self.updateVisibility()
        NotificationCenter.default.post(name: .toggleOneView, object: nil)
        NotificationCenter.default.post(name: .moduleRearrange, object: nil)
    }

    @objc private func toggleNetwork(_ sender: NSButton) {
        // Menu-bar speed is independent from the Network row in the Combined panel.
        self.showNetwork = sender.state == .on
        modules.first(where: { $0.name == "Network" })?.syncCombinedState()
        NotificationCenter.default.post(name: .moduleRearrange, object: nil)
    }
    @objc private func reload() {
        self.moduleList.reload()
    }
}

// Vertical, reorderable list of modules with an include checkbox.
private class CombinedModuleListView: NSStackView {
    init() {
        super.init(frame: .zero)
        self.orientation = .vertical
        self.spacing = 0
        self.translatesAutoresizingMaskIntoConstraints = false
        self.setHuggingPriority(.defaultLow, for: .horizontal)
        self.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.wantsLayer = true
        self.reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func setEnabled(_ enabled: Bool) {
        self.alphaValue = enabled ? 1.0 : 0.45
    }

    @objc fileprivate func reload() {
        self.subviews.forEach { $0.removeFromSuperview() }
        let ordered = modules.filter({ $0.available }).enumerated().sorted { a, b in
            if a.element.combinedPosition == b.element.combinedPosition {
                return a.offset < b.offset
            }
            return a.element.combinedPosition < b.element.combinedPosition
        }.map { $0.element }
        ordered.forEach { m in
            let row = CombinedModuleRow(module: m)
            // Add to the hierarchy first (so the two views share a common ancestor),
            // then pin each row to the list width so the column grid (checkbox / icon /
            // name / handle) aligns across every row regardless of the localized name length.
            self.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        guard let target = self.arrangedSubviews.first(where: { $0 is CombinedModuleRow && $0.hitTest(location) != nil }) as? CombinedModuleRow else {
            super.mouseDown(with: event)
            return
        }
        let localPoint = target.convert(event.locationInWindow, from: nil)
        if let hit = target.hitTest(localPoint), hit is NSControl {
            super.mouseDown(with: event)
            return
        }
        self.startDrag(row: target, event: event)
    }

    private func startDrag(row: CombinedModuleRow, event: NSEvent) {
        guard let window = self.window else {
            super.mouseDown(with: event)
            return
        }

        let copy = ViewCopy(row)
        copy.zPosition = 2
        copy.transform = CATransform3DMakeScale(1.01, 1.01, 1)
        row.subviews.forEach { $0.isHidden = true }
        self.layer?.addSublayer(copy)
        defer {
            copy.removeFromSuperlayer()
            row.subviews.forEach { $0.isHidden = false }
        }

        var newIdx = -1
        let originCenter = row.frame.midY
        let originY = row.frame.origin.y
        let p0 = self.convert(event.locationInWindow, from: nil).y

        window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: 1e6, mode: .eventTracking) { event, stop in
            guard let event = event else {
                stop.pointee = true
                return
            }
            if event.type == .leftMouseDragged {
                let p1 = self.convert(event.locationInWindow, from: nil).y
                let diff = p1 - p0

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                copy.frame.origin.y = originY + diff
                CATransaction.commit()

                let reordered = self.arrangedSubviews.map {
                    (view: $0, y: $0 !== row ? $0.frame.midY : originCenter + diff)
                }.sorted { $0.y > $1.y }.map { $0.view }

                guard let nextIndex = reordered.firstIndex(of: row),
                      let prevIndex = self.arrangedSubviews.firstIndex(of: row) else {
                    stop.pointee = true
                    return
                }
                if nextIndex != prevIndex {
                    newIdx = nextIndex
                    // Reorder only inside NSStackView's arranged-subview list. Removing the row
                    // from its superview deactivates `row.widthAnchor == self.widthAnchor`; after
                    // reinsertion AppKit then sizes the row to its intrinsic content width and
                    // centers it, which makes dragged rows visibly collapse toward the middle.
                    // Keeping the row in the view hierarchy preserves the full-width constraint
                    // and the shared checkbox / icon / name / handle column grid.
                    self.removeArrangedSubview(row)
                    self.insertArrangedSubview(row, at: newIdx)
                    self.layoutSubtreeIfNeeded()
                    self.persistOrder()
                }
            } else {
                if newIdx != -1 {
                    self.persistOrder()
                    NotificationCenter.default.post(name: .moduleRearrange, object: nil)
                    // Rebuild rows on the next main-loop turn after AppKit finishes the drag
                    // transaction. This guarantees that the released row is recreated with the
                    // normal full-width constraint and that the visible order comes from the
                    // positions just persisted above.
                    DispatchQueue.main.async { [weak self] in
                        self?.reload()
                    }
                }
                row.mouseUp(with: event)
                stop.pointee = true
            }
        }
    }

    private func persistOrder() {
        // NSStackView may keep its ordinary `subviews` array in a different order after
        // remove/insert operations. The visual order is authoritative and lives in
        // `arrangedSubviews`, so persist positions from that list.
        for (i, v) in self.arrangedSubviews.compactMap({ $0 as? CombinedModuleRow }).enumerated() {
            v.module.combinedPosition = i
        }
    }
}

private class CombinedModuleRow: NSStackView {
    fileprivate let module: Module

    init(module: Module) {
        self.module = module
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 36))

        self.orientation = .horizontal
        self.spacing = 8
        self.alignment = .centerY
        self.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        self.identifier = NSUserInterfaceItemIdentifier(rawValue: module.name)
        // Stretch the row so all rows share the same width and the column grid stays aligned.
        self.setHuggingPriority(.defaultLow, for: .horizontal)
        self.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Combined owns this selection independently of the module's standalone tab.
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(self.toggleInclude))
        checkbox.state = module.combinedIncluded ? .on : .off
        checkbox.controlSize = .regular
        checkbox.contentTintColor = .controlAccentColor
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        // Fixed-width checkbox column so every tick sits on the same vertical line.
        checkbox.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let contentColor: NSColor = .labelColor

        let iconView = NSImageView()
        iconView.image = module.config.icon
        iconView.contentTintColor = contentColor
        // A single symbol point size for all glyphs keeps the icon column aligned despite glyph shape differences.
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        // Fixed-width icon column; glyphs are centered inside it.
        iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let nameField = NSTextField(labelWithString: localizedString(module.name))
        nameField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        nameField.textColor = contentColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.alignment = .left
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let handle = NSImageView()
        handle.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "reorder")
        handle.contentTintColor = .tertiaryLabelColor
        handle.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        handle.imageScaling = .scaleProportionallyDown
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.widthAnchor.constraint(equalToConstant: 20).isActive = true

        self.addArrangedSubview(checkbox)
        self.addArrangedSubview(iconView)
        self.addArrangedSubview(nameField)
        self.addArrangedSubview(handle)

        self.heightAnchor.constraint(equalToConstant: 38).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        self.addTrackingArea(NSTrackingArea(
            rect: self.bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
    }

    @objc private func toggleInclude(_ sender: NSButton) {
        self.module.combinedIncluded = sender.state == .on
        self.module.syncCombinedState()
        NotificationCenter.default.post(name: .moduleRearrange, object: nil)
    }
}

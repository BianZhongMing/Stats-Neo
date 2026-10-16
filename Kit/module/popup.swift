//
//  popup.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 11/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public final class PopupCache<T> {
    public var value: T?
    public var initialized: Bool = false
    
    public init() {}
    
    public func apply(_ value: T, visible: Bool, render: (T) -> Void) {
        self.value = value
        if visible || !self.initialized {
            render(value)
            self.initialized = true
        }
    }
    
    public func replay(render: (T) -> Void) {
        if let v = self.value { render(v) }
    }
}

public protocol Popup_p: NSView {
    var keyboardShortcut: [UInt16] { get }
    var sizeCallback: ((NSSize) -> Void)? { get set }
    
    func settings() -> NSView?
    
    func appear()
    func disappear()
    func setKeyboardShortcut(_ binding: [UInt16])
}

open class PopupWrapper: NSStackView, Popup_p {
    public var title: String
    public var keyboardShortcut: [UInt16] = []
    open var sizeCallback: ((NSSize) -> Void)? = nil
    
    public init(_ typ: ModuleType, frame: NSRect) {
        self.title = typ.stringValue
        self.keyboardShortcut = Store.shared.array(key: "\(typ.stringValue)_popup_keyboardShortcut", defaultValue: []) as? [UInt16] ?? []
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func settings() -> NSView? { return nil }
    open func appear() {}
    open func disappear() {}
    
    open func setKeyboardShortcut(_ binding: [UInt16]) {
        self.keyboardShortcut = binding
        Store.shared.set(key: "\(self.title)_popup_keyboardShortcut", value: binding)
    }
    
    public func apply<T>(_ value: T, to cache: PopupCache<T>, render: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            cache.apply(value, visible: self.window?.isVisible ?? false, render: render)
        }
    }
    
    public func replay<T>(_ cache: PopupCache<T>, render: (T) -> Void) {
        cache.replay(render: render)
    }
}

public class PopupWindow: NSWindow, NSWindowDelegate {
    private let viewController: PopupViewController
    internal var locked: Bool = false
    internal var openedBy: widget_t? = nil
    
    public init(title: String, module: ModuleType, view: Popup_p?, visibilityCallback: @escaping (_ state: Bool) -> Void) {
        self.viewController = PopupViewController(module: module)
        self.viewController.setup(title: title, view: view)
        
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        self.viewController.visibilityCallback = { [weak self] state in
            self?.locked = false
            visibilityCallback(state)
        }
        
        self.title = title
        self.titleVisibility = .hidden
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.backgroundColor = .clear
        if module == .combined {
            self.isOpaque = false
        }
        self.hasShadow = true
        self.setIsVisible(false)
        self.delegate = self
    }
    
    public func windowWillMove(_ notification: Notification) {
        self.viewController.setCloseButton(true)
        self.locked = true
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        if self.locked {
            return
        }
        
        self.viewController.setCloseButton(false)
        self.setIsVisible(false)
    }
}

internal class PopupViewController: NSViewController {
    fileprivate var visibilityCallback: (_ state: Bool) -> Void = {_ in }
    private var popup: PopupView
    
    public init(module: ModuleType) {
        let contentWidth: CGFloat = module == .combined ? CombinedPortalStyle.contentWidth : Constants.Popup.width
        let horizontalMargin: CGFloat = module == .combined ? 8 : Constants.Popup.margins
        let headerHeight: CGFloat = module == .combined ? 56 : Constants.Popup.headerHeight
        self.popup = PopupView(frame: NSRect(
            x: 0,
            y: 0,
            width: contentWidth + (horizontalMargin * 2),
            height: Constants.Popup.height + headerHeight
        ), module: module)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self.popup
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.popup.appear()
        self.visibilityCallback(true)
        NotificationCenter.default.post(name: .popupVisibilityChanged, object: nil, userInfo: ["state": true])
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        self.popup.disappear()
        self.visibilityCallback(false)
        NotificationCenter.default.post(name: .popupVisibilityChanged, object: nil, userInfo: ["state": false])
    }
    
    fileprivate func setup(title: String, view: Popup_p?) {
        self.title = title
        self.popup.setTitle(title)
        self.popup.setView(view)
    }
    
    fileprivate func setCloseButton(_ state: Bool) {
        self.popup.setCloseButton(state)
    }
}

internal class PopupView: NSView {
    private var view: Popup_p? = nil
    private let module: ModuleType
    private let contentMargin: CGFloat
    private let headerHeight: CGFloat
    
    private var foreground: NSVisualEffectView
    private var background: NSView
    
    private let header: HeaderView
    private let body: NSScrollView
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.width, height: self.frame.height)
    }
    private var windowHeight: CGFloat?
    private var containerHeight: CGFloat?
    
    init(frame: NSRect, module: ModuleType) {
        self.module = module
        self.contentMargin = module == .combined ? 8 : Constants.Popup.margins
        self.headerHeight = module == .combined ? 56 : Constants.Popup.headerHeight
        self.header = HeaderView(frame: NSRect(
            x: 0,
            y: frame.height - self.headerHeight,
            width: frame.width,
            height: self.headerHeight
        ), module: module)
        self.body = NSScrollView(frame: NSRect(
            x: self.contentMargin,
            y: self.contentMargin,
            width: frame.width - self.contentMargin*2,
            height: frame.height - self.header.frame.height - self.contentMargin*2
        ))
        self.windowHeight = NSScreen.main?.visibleFrame.height
        self.containerHeight = self.body.documentView?.frame.height
        
        self.foreground = NSVisualEffectView(frame: frame)
        self.foreground.material = module == .combined ? .popover : .titlebar
        self.foreground.blendingMode = .behindWindow
        self.foreground.state = .active
        self.foreground.wantsLayer = true
        self.foreground.layer?.backgroundColor = NSColor.clear.cgColor
        self.foreground.layer?.cornerRadius = module == .combined ? 16 : 6
        self.foreground.layer?.cornerCurve = .continuous
        self.foreground.layer?.masksToBounds = true
        
        self.background = NSView(frame: frame)
        self.background.wantsLayer = true
        self.foreground.addSubview(self.background)
        
        super.init(frame: frame)
        
        self.body.drawsBackground = false
        self.body.translatesAutoresizingMaskIntoConstraints = true
        self.body.borderType = .noBorder
        self.body.hasVerticalScroller = true
        self.body.hasHorizontalScroller = false
        self.body.autohidesScrollers = true
        self.body.horizontalScrollElasticity = .none

        if self.module == .combined {
            self.applyCombinedAppearance()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.combinedAppearanceChanged),
                name: .combinedAppearanceChanged,
                object: nil
            )
        }
        
        self.addSubview(self.foreground, positioned: .below, relativeTo: .none)
        self.addSubview(self.header)
        self.addSubview(self.body)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if self.module == .combined {
            NotificationCenter.default.removeObserver(self, name: .combinedAppearanceChanged, object: nil)
        }
    }

    @objc private func combinedAppearanceChanged() {
        self.applyCombinedAppearance()
    }

    private func applyCombinedAppearance() {
        let value = Store.shared.string(key: "CombinedModules_appearance", defaultValue: CombinedAppearance.system.rawValue)
        self.appearance = CombinedAppearance(rawValue: value)?.appearance
        self.invalidateAppearance(in: self)
        self.needsDisplay = true
        self.displayIfNeeded()

        // Applying a forced appearance while the popup is hidden does not reliably invalidate
        // every descendant's backing store. Repeat on the next run-loop turn so custom-drawn
        // views (notably the battery status badge) render entirely in the selected appearance.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.invalidateAppearance(in: self)
            self.displayIfNeeded()
        }
    }

    private func invalidateAppearance(in view: NSView) {
        view.needsDisplay = true
        view.layer?.setNeedsDisplay()
        view.subviews.forEach { self.invalidateAppearance(in: $0) }
    }
    
    override func updateLayer() {
        if self.module == .combined {
            self.background.layer?.backgroundColor = (self.isDarkMode
                ? NSColor(red: 29/255, green: 35/255, blue: 58/255, alpha: 0.34)
                : NSColor(red: 238/255, green: 243/255, blue: 252/255, alpha: 0.28)).cgColor
            self.background.layer?.cornerRadius = 16
            self.background.layer?.cornerCurve = .continuous
            self.background.layer?.borderWidth = 0.6
            self.background.layer?.borderColor = NSColor.white.withAlphaComponent(self.isDarkMode ? 0.16 : 0.38).cgColor
        } else {
            self.background.layer?.backgroundColor = self.isDarkMode ? .clear : NSColor.white.cgColor
        }
    }
    
    fileprivate func setView(_ view: Popup_p?) {
        self.view = view
        
        var isScrollVisible: Bool = false
        var size: NSSize = NSSize(
            width: (view?.frame.width ?? Constants.Popup.width) + (self.contentMargin*2),
            height: (view?.frame.height ?? 0) + self.headerHeight + (self.contentMargin*2)
        )
        
        self.windowHeight = NSScreen.main?.visibleFrame.height // for height recalculate when appear/disappear
        self.containerHeight = self.body.documentView?.frame.height // for scroll diff calculation
        if let screenHeight = NSScreen.main?.visibleFrame.height, size.height > screenHeight {
            size.height = screenHeight - Constants.Widget.height
            isScrollVisible = true
        }
        if let screenWidth = NSScreen.main?.visibleFrame.width, size.width > screenWidth {
            size.width = screenWidth
        }
        
        self.setFrameSize(size)
        self.foreground.setFrameSize(size)
        self.background.setFrameSize(size)
        self.resizeBody(size, scrollVisible: isScrollVisible)
        self.header.setFrameOrigin(NSPoint(x: 0, y: size.height - self.headerHeight))
        
        if let view = view {
            self.body.documentView = view
            view.sizeCallback = { [weak self] size in
                self?.recalculateHeight(size)
            }
        }
    }
    
    fileprivate func setTitle(_ newTitle: String) {
        self.header.setTitle(newTitle)
    }
    
    fileprivate func setCloseButton(_ state: Bool) {
        self.header.setCloseButton(state)
    }
    
    internal func appear() {
        self.view?.appear()
        
        self.display()
        self.body.subviews.first?.display()
        
        if let screenHeight = NSScreen.main?.visibleFrame.height, let size = self.body.documentView?.frame.size {
            if screenHeight != self.windowHeight {
                self.recalculateHeight(size)
            }
        }
        
        if let documentView = self.body.documentView {
            documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
        }
    }
    internal func disappear() {
        self.header.setCloseButton(false)
        self.view?.disappear()
    }
    
    private func recalculateHeight(_ size: NSSize) {
        var isScrollVisible: Bool = false
        var windowSize: NSSize = NSSize(
            width: size.width + (self.contentMargin*2),
            height: size.height + self.headerHeight + (self.contentMargin*2)
        )
        let h0 = self.containerHeight ?? 0
        
        self.windowHeight = NSScreen.main?.visibleFrame.height // for height recalculate when appear/disappear
        self.containerHeight = self.body.documentView?.frame.height // for scroll diff calculation
        if let screenHeight = NSScreen.main?.visibleFrame.height, windowSize.height > screenHeight {
            windowSize.height = screenHeight - Constants.Widget.height
            isScrollVisible = true
        }
        if let screenWidth = NSScreen.main?.visibleFrame.width, windowSize.width > screenWidth {
            windowSize.width = screenWidth
        }
        
        self.window?.setContentSize(windowSize)
        self.foreground.setFrameSize(windowSize)
        self.background.setFrameSize(windowSize)
        self.resizeBody(windowSize, scrollVisible: isScrollVisible)
        self.header.setFrameOrigin(NSPoint(
            x: self.header.frame.origin.x,
            y: self.body.frame.height + (self.contentMargin*2)
        ))
        
        if let documentView = self.body.documentView {
            let diff = h0 - (self.body.documentView?.frame.height ?? 0)
            documentView.scroll(NSPoint(
                x: 0,
                y: self.body.documentVisibleRect.origin.y - (diff < 0 ? diff : 0)
            ))
        }
    }
    
    private func resizeBody(_ windowSize: NSSize, scrollVisible: Bool) {
        let offset: CGFloat = scrollVisible ? 20 : 0
        let isRTL = self.body.userInterfaceLayoutDirection == .rightToLeft
        self.body.frame = NSRect(
            x: self.contentMargin - (isRTL ? offset : 0),
            y: self.contentMargin,
            width: windowSize.width - (self.contentMargin*2) + offset,
            height: windowSize.height - self.headerHeight - (self.contentMargin*2)
        )
    }
}

internal class HeaderView: NSStackView {
    private var titleView: NSTextField? = nil
    private var activityButton: NSButton?
    
    private var title: String = ""
    private var isCloseAction: Bool = false
    private let activityMonitor: URL?
    private let calendar: URL?
    private var module: ModuleType
    
    init(frame: NSRect, module: ModuleType) {
        self.module = module
        self.activityMonitor = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor")
        self.calendar = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        
        self.orientation = .horizontal
        self.distribution = .gravityAreas
        self.spacing = 0
        
        let activity = NSButtonWithPadding()
        activity.frame = CGRect(x: 0, y: 0, width: 24, height: self.frame.height)
        activity.horizontalPadding = activity.frame.height - 24
        activity.bezelStyle = .regularSquare
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.imageScaling = .scaleNone
        activity.contentTintColor = .lightGray
        activity.isBordered = false
        activity.target = self
        activity.focusRingType = .none
        self.activityButton = activity
        self.setupActionButton()
        
        let title = NSTextField(frame: NSRect(
            x: 0,
            y: 0,
            width: frame.width/2,
            height: self.module == .combined ? 20 : 18
        ))
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .textColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 16, weight: self.module == .combined ? .semibold : .regular)
        title.stringValue = ""
        self.titleView = title

        let centerView: NSView
        if self.module == .combined {
            let titleContainer = NSStackView()
            titleContainer.orientation = .vertical
            titleContainer.alignment = .centerX
            titleContainer.spacing = 1
            titleContainer.addArrangedSubview(title)
            let subtitle = NSTextField(labelWithString: "COMBINED")
            subtitle.font = NSFont.systemFont(ofSize: 8.5, weight: .medium)
            subtitle.textColor = .tertiaryLabelColor
            subtitle.alignment = .center
            titleContainer.addArrangedSubview(subtitle)
            centerView = titleContainer
        } else {
            centerView = title
        }
        
        let settings = NSButtonWithPadding()
        settings.frame = CGRect(x: 0, y: 0, width: 24, height: self.frame.height)
        settings.horizontalPadding = activity.frame.height - 24
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleNone
        settings.image = iconFromSymbol(name: "command", scale: .large)
        settings.contentTintColor = .lightGray
        settings.isBordered = false
        settings.action = #selector(self.openSettings)
        settings.target = self
        settings.toolTip = localizedString("Open module")
        settings.focusRingType = .none
        
        if self.module == .combined {
            activity.imageScaling = .scaleProportionallyDown
            settings.imageScaling = .scaleProportionallyDown
            settings.contentTintColor = .systemPurple
        }

        self.addArrangedSubview(activity)
        self.addArrangedSubview(centerView)
        self.addArrangedSubview(settings)
        
        NSLayoutConstraint.activate([
            centerView.widthAnchor.constraint(
                equalToConstant: self.frame.width - activity.intrinsicContentSize.width - settings.intrinsicContentSize.width
            )
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setTitle(_ newTitle: String) {
        self.title = newTitle
        self.titleView?.stringValue = localizedString(newTitle)
    }
    
    private func setupActionButton() {
        guard let button = self.activityButton else { return }
        
        if self.isCloseAction {
            button.action = #selector(self.closePopup)
            button.image = iconFromSymbol(name: "xmark.circle.fill", scale: .xlarge)
            button.toolTip = localizedString("Close")
            return
        }
        
        if self.module == .clock {
            button.action = #selector(self.openCalendar)
            button.image = iconFromSymbol(name: "calendar", scale: .large)
            button.toolTip = localizedString("Open Calendar")
            return
        } else if self.module == .remote {
            button.action = #selector(self.openSystemStats)
            button.image = iconFromSymbol(name: "globe", scale: .large)
            button.toolTip = localizedString("Open System Stats")
            return
        }
        
        button.action = #selector(self.openActivityMonitor)
        button.image = iconFromSymbol(name: self.module == .combined ? "chart.bar.xaxis" : "chart.bar.fill", scale: self.module == .combined ? .large : .medium)
        button.contentTintColor = self.module == .combined ? .controlAccentColor : .lightGray
        button.toolTip = localizedString("Open Activity Monitor")
    }
    
    @objc func openActivityMonitor() {
        guard let app = self.activityMonitor else { return }
        if let tab = self.module.activityMonitorTab {
            UserDefaults(suiteName: "com.apple.ActivityMonitor")?.set(tab, forKey: "SelectedTab")
        }
        NSWorkspace.shared.open([], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
    
    @objc func openCalendar() {
        guard let app = self.calendar else { return }
        NSWorkspace.shared.open([], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
    
    @objc func openSystemStats() {
        guard let url = URL(string: "https://app.system-stats.com") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc func openSettings() {
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.title])
    }
    
    @objc private func closePopup() {
        self.window?.setIsVisible(false)
        self.setCloseButton(false)
        return
    }
    
    fileprivate func setCloseButton(_ state: Bool) {
        guard state != self.isCloseAction else { return }
        self.isCloseAction = state
        self.setupActionButton()
    }
}

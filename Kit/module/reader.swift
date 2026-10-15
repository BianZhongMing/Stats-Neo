//
//  reader.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Reader_p: AnyObject {
    var popup: Bool { get }
    var preview: Bool { get }
    var sleep: Bool { get }
    var active: Bool { get }
    
    func setup()
    func read()
    func terminate()
    
    func start()
    func pause()
    func stop()
    func readNow()
    
    func lock()
    func unlock()
    
    func initStoreValues(title: String)
    func setInterval(_ value: Int)
    func setRuntimeInterval(_ value: Int?)
    func setSamplingClass(_ value: ReaderSamplingClass)
    func refreshEnergyMode()
    func sleepMode(state: Bool)
}

public protocol ReaderInternal_p {
    associatedtype T
    
    var value: T? { get }
    func read()
}

open class Reader<T: Codable>: NSObject, ReaderInternal_p {
    public var log: NextLog {
        NextLog.shared.copy(category: "\(String(describing: self))")
    }
    private let valueQueue = DispatchQueue(label: "eu.exelban.readerActiveQueue")
    private var _value: T?
    public var value: T? {
        get { self.valueQueue.sync { self._value } }
        set { self.valueQueue.sync { self._value = newValue } }
    }
    public var name: String {
        String(NSStringFromClass(type(of: self)).split(separator: ".").last ?? "unknown")
    }
    
    public var interval: Double? = nil
    public var defaultInterval: Int = 1
    private var configuredInterval: Int?
    private var runtimeInterval: Int?
    private var samplingClass: ReaderSamplingClass = .regular
    public var popup: Bool = false
    public var preview: Bool = false
    public var sleep: Bool = false
    
    public var alignToSecondBoundary: Bool = false
    public var alignOffset: TimeInterval = 0
    
    public var callbackHandler: (T?) -> Void
    
    private let module: ModuleType
    private var history: Bool
    private var repeatTask: Repeater?
    private var locked: Bool = true
    private var initlizalized: Bool = false
    
    private let activeQueue = DispatchQueue(label: "eu.exelban.readerActiveQueue")
    private var _active: Bool = false
    public var active: Bool {
        get { self.activeQueue.sync { self._active } }
        set { self.activeQueue.sync { self._active = newValue } }
    }

    private let readStateQueue = DispatchQueue(label: "eu.exelban.readerReadState")
    private var readInProgress = false
    
    private var lastDBWrite: Date? = nil
    
    private var alignGeneration: UInt = 0
    private let alignQueue = DispatchQueue(label: "eu.exelban.readerAlignQueue")
    
    public init(_ module: ModuleType, popup: Bool = false, preview: Bool = false, history: Bool = false, callback: @escaping (T?) -> Void = {_ in }) {
        self.popup = popup
        self.preview = preview
        self.module = module
        self.history = history
        self.callbackHandler = callback
        
        super.init()
        DB.shared.setup(T.self, "\(module.stringValue)@\(self.name)")
        if let lastValue = DB.shared.findOne(T.self, key: "\(module.stringValue)@\(self.name)") {
            self.value = lastValue
            callback(lastValue)
        }
        self.setup()
        
        debug("Successfully initialize reader", log: self.log)
    }
    
    deinit {
        DB.shared.insert(key: "\(self.module.stringValue)@\(self.name)", value: self.value, ts: self.history)
    }
    
    public func initStoreValues(title: String) {
        guard self.configuredInterval == nil else { return }
        let updateInterval = Store.shared.int(key: "\(title)_updateInterval", defaultValue: self.defaultInterval)
        self.configuredInterval = updateInterval
        self.applyEffectiveInterval()
    }
    
    public func callback(_ value: T?) {
        let moduleKey = "\(self.module.stringValue)@\(self.name)"
        self.value = value
        if let value {
            self.callbackHandler(value)
            SystemStats.shared.send(key: moduleKey, value: value)
            if let ts = self.lastDBWrite, let interval = self.interval, Date().timeIntervalSince(ts) > interval * 10 {
                DB.shared.insert(key: moduleKey, value: value, ts: self.history)
                self.lastDBWrite = Date()
            } else if self.lastDBWrite == nil {
                DB.shared.insert(key: moduleKey, value: value, ts: self.history)
                self.lastDBWrite = Date()
            }
        }
    }
    
    open func read() {}
    open func setup() {}
    open func terminate() {}
    
    public func readNow() {
        self.dispatchRead()
    }

    private func performRead() {
        let shouldRead = self.readStateQueue.sync { () -> Bool in
            if self.readInProgress { return false }
            self.readInProgress = true
            return true
        }
        guard shouldRead else { return }
        defer { self.readStateQueue.sync { self.readInProgress = false } }
        self.read()
    }

    private func dispatchRead() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performRead()
        }
    }

    open func start() {
        if (self.popup || self.preview || self.sleep) && self.locked {
            self.dispatchRead()
            return
        }
        
        self.alignQueue.sync {
            if self.alignToSecondBoundary {
                if self.repeatTask == nil {
                    self.startAlignedRepeater()
                } else {
                    self.repeatTask?.start()
                }
            } else if !self.initlizalized {
                self.startNormalRepeater()
                self.dispatchRead()
                self.repeatTask?.start()
                self.initlizalized = true
            } else {
                self.repeatTask?.start()
            }
        }
        
        self.active = true
    }
    
    open func pause() {
        self.alignQueue.sync {
            self.alignGeneration &+= 1
            self.repeatTask?.pause()
        }
        self.active = false
    }
    
    open func stop() {
        self.alignQueue.sync {
            self.alignGeneration &+= 1
            self.repeatTask?.pause()
            self.repeatTask = nil
            self.initlizalized = false
        }
        self.active = false
    }
    
    public func setInterval(_ value: Int) {
        self.configuredInterval = max(1, value)
        self.applyEffectiveInterval()
    }

    public func setRuntimeInterval(_ value: Int?) {
        self.runtimeInterval = value.map { max(1, $0) }
        self.applyEffectiveInterval()
    }

    public func setSamplingClass(_ value: ReaderSamplingClass) {
        self.samplingClass = value
        self.applyEffectiveInterval()
    }

    public func refreshEnergyMode() {
        self.runtimeInterval = nil
        self.applyEffectiveInterval()
    }

    private func applyEffectiveInterval() {
        let configured = self.configuredInterval ?? self.defaultInterval
        let energyInterval = EnergyMode.effective.interval(configured: configured, samplingClass: self.samplingClass)
        let effective = max(1, self.runtimeInterval ?? energyInterval)
        guard self.interval != Double(effective) else { return }

        debug("Set effective update interval: \(effective) sec", log: self.log)
        self.interval = Double(effective)

        self.alignQueue.sync {
            if self.alignToSecondBoundary {
                self.alignGeneration &+= 1
                self.repeatTask?.pause()
                self.repeatTask = nil
                if self.active {
                    self.startAlignedRepeater()
                }
            } else {
                self.repeatTask?.reset(seconds: effective, restart: self.active)
            }
        }
    }
    
    public func save(_ value: T) {
        DB.shared.insert(key: "\(self.module.stringValue)@\(self.name)", value: value, ts: self.history, force: true)
    }
    
    private func delayToNextSecondBoundary() -> TimeInterval {
        let now = Date().addingTimeInterval(self.alignOffset)
        let fractional = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0)
        let baseDelay = (fractional == 0) ? 0.0 : (1.0 - fractional)
        let safety: TimeInterval = 0.005 // 5ms past the boundary
        return baseDelay + safety
    }
    
    private func startNormalRepeater() {
        guard let interval = self.interval, self.repeatTask == nil else { return }
        
        if !self.popup && !self.preview {
            debug("Set up update interval: \(Int(interval)) sec", log: self.log)
        }
        
        self.repeatTask = Repeater(seconds: Int(interval)) { [weak self] in
            self?.performRead()
        }
    }
    
    private func startAlignedRepeater() {
        guard let interval = self.interval, self.repeatTask == nil else { return }
        
        if !self.popup && !self.preview {
            debug("Set up update interval: \(Int(interval)) sec (aligned)", log: self.log)
        }
        
        self.alignGeneration &+= 1
        let generation = self.alignGeneration
        self.alignQueue.asyncAfter(deadline: .now() + self.delayToNextSecondBoundary()) { [weak self] in
            guard let self, self.alignGeneration == generation, self.repeatTask == nil else { return }

            self.dispatchRead()
            self.repeatTask = Repeater(seconds: Int(interval), group: 1) { [weak self] in
                self?.performRead()
            }
            self.repeatTask?.start()
        }
    }
    
    public func sleepMode(state: Bool) {
        guard state != self.sleep else { return }

        debug("Sleep mode: \(state ? "on" : "off")", log: self.log)
        self.sleep = state

        if state {
            if self.locked {
                self.pause()
            }
        } else {
            self.start()
        }
    }
}

extension Reader: Reader_p {
    public func lock() {
        self.locked = true
    }
    
    public func unlock() {
        self.locked = false
    }
}

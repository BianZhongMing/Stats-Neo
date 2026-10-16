//
//  portal.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 20/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Portal: PortalWrapper {
    private var circle: PieChartView = PieChartView(drawValue: true)
    private var chart: CombinedHistoryBarsView? = nil
    
    private var nameField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var readField: NSTextField? = nil
    private var writeField: NSTextField? = nil
    
    private var valueColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_valueColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var readColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_readColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var writeColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_writeColor", defaultValue: SColor.secondRed.key)).additional as! NSColor
    }
    
    public var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(ModuleType.disk.stringValue)_base", defaultValue: "byte")) ?? .byte
    }
    public var speedUnit: String {
        networkSpeedUnit(from: Store.shared.string(key: "\(ModuleType.disk.stringValue)_speedUnit", defaultValue: NetworkSpeedUnitAuto)).key
    }
    
    private var initialized: Bool = false
    
    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        self.body.spacing = 10

        let top = NSStackView()
        top.orientation = .horizontal
        top.distribution = .fill
        top.alignment = .centerY
        top.spacing = 12
        top.heightAnchor.constraint(equalToConstant: 84).isActive = true
        let circle = self.circleView()
        circle.widthAnchor.constraint(equalToConstant: 116).isActive = true
        top.addArrangedSubview(circle)
        top.addArrangedSubview(self.detailsView())

        let bottom = NSStackView()
        bottom.orientation = .horizontal
        bottom.distribution = .fill
        bottom.alignment = .centerY
        bottom.spacing = 10
        bottom.heightAnchor.constraint(equalToConstant: 52).isActive = true
        let io = self.ioView()
        io.widthAnchor.constraint(equalToConstant: 150).isActive = true
        bottom.addArrangedSubview(io)
        bottom.addArrangedSubview(self.chartView())

        self.body.addArrangedSubview(top)
        self.body.addArrangedSubview(bottom)
    }
    
    private func circleView() -> NSView {
        let view = NSStackView()
        
        view.heightAnchor.constraint(equalToConstant: 84).isActive = true
        view.edgeInsets = NSEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
        
        view.addArrangedSubview(self.circle)
        
        return view
    }
    
    private func detailsView() -> NSView {
        let view = combinedMetricStack(spacing: 5)
        self.nameField = combinedDataRow(view, title: "\(localizedString("Name")):")
        self.usedField = combinedDataRow(view, title: "\(localizedString("Used")):")
        self.freeField = combinedDataRow(view, title: "\(localizedString("Free")):")
        return view
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        CombinedPortalStyle.surface(view)
        
        let chart = CombinedHistoryBarsView(count: 12, firstColor: self.writeColor, secondColor: self.readColor)
        self.chart = chart
        
        view.addArrangedSubview(chart)
        
        return view
    }
    
    private func ioView() -> NSView {
        let view = combinedMetricStack(spacing: 5)
        self.writeField = combinedDataRow(view, title: "\(localizedString("Write")):", color: self.writeColor)
        self.readField = combinedDataRow(view, title: "\(localizedString("Read")):", color: self.readColor)
        return view
    }
    
    internal func utilizationCallback(_ value: drive) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.nameField?.stringValue = value.mediaName
                self.usedField?.stringValue = DiskSize(value.size - value.free).getReadableMemory()
                self.freeField?.stringValue = DiskSize(value.free).getReadableMemory()
                
                self.circle.toolTip = "\(localizedString("Disk usage")): \(Int(value.percentage*100))%"
                self.circle.setValue(value.percentage)
                self.circle.setSegments([
                    ColorValue(value.percentage, color: self.valueColor)
                ])
                self.initialized = true
            }
        })
    }
    
    internal func activityCallback(_ value: drive) {
        DispatchQueue.main.async(execute: {
            self.chart?.addValue(first: Double(value.activity.write), second: Double(value.activity.read))
            
            self.writeField?.stringValue = Units(bytes: value.activity.write).getReadableSpeed(base: self.base, unit: self.speedUnit)
            self.readField?.stringValue = Units(bytes: value.activity.read).getReadableSpeed(base: self.base, unit: self.speedUnit)
        })
    }
}

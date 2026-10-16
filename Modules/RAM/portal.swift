//
//  portal.swift
//  RAM
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Portal: PortalWrapper {
    private var circle: PieChartView = PieChartView(drawValue: true)
    
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    private var swapField: NSTextField? = nil
    private var pressureLevelField: NSTextField? = nil
    
    private var initialized: Bool = false
    
    private var appColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_appColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var wiredColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_wiredColor", defaultValue: SColor.secondOrange.key)).additional as! NSColor
    }
    private var compressedColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_compressedColor", defaultValue: SColor.pink.key)).additional as! NSColor
    }
    private var freeColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_freeColor", defaultValue: SColor.lightGray.key)).additional as! NSColor
    }
    
    public override func load() {
        self.body.distribution = .fill
        self.body.alignment = .centerY
        self.body.spacing = 14
        let circle = self.circleView()
        circle.widthAnchor.constraint(equalToConstant: 116).isActive = true
        let details = self.detailsView()
        self.body.addArrangedSubview(circle)
        self.body.addArrangedSubview(details)
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
        self.usedField = combinedDataRow(view, title: "\(localizedString("Used")):")
        self.freeField = combinedDataRow(view, title: "\(localizedString("Free")):")
        self.swapField = combinedDataRow(view, title: "Swap:")
        self.pressureLevelField = combinedDataRow(view, title: "\(localizedString("Pressure")):")
        return view
    }
    
    internal func callback(_ value: RAM_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.usedField?.stringValue = Units(bytes: Int64(value.used)).getReadableMemory(style: .memory)
                self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory(style: .memory)
                self.swapField?.stringValue = Units(bytes: Int64(value.swap.used)).getReadableMemory(style: .memory)
                self.pressureLevelField?.stringValue = localizedString(value.pressure.value.rawValue.capitalized)
                self.pressureLevelField?.textColor = value.pressure.value.pressureColor()
                
                self.usedField?.toolTip = "\(Int(value.usage.rounded(toPlaces: 2) * 100))%"
                self.freeField?.toolTip = "\(Int((1-value.usage).rounded(toPlaces: 2) * 100))%"
                if let level = memoryPressureLevels.first(where: { $0.additional as? RAMPressure == value.pressure.value }) {
                    self.pressureLevelField?.toolTip = localizedString(level.value)
                }
                
                self.circle.toolTip = "\(localizedString("Memory usage")): \(Int(value.usage*100))%"
                self.circle.setValue(value.usage)
                self.circle.setSegments([
                    ColorValue(value.app/value.total, color: self.appColor),
                    ColorValue(value.wired/value.total, color: self.wiredColor),
                    ColorValue(value.compressed/value.total, color: self.compressedColor)
                ])
                self.circle.setNonActiveSegmentColor(self.freeColor)
                
                self.initialized = true
            }
        })
    }
}

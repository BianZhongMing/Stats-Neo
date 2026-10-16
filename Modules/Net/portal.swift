//
//  portal.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 18/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Portal: PortalWrapper {
    private var chart: CombinedHistoryBarsView? = nil
    private var initialized: Bool = false
    
    private var uploadField: NSTextField? = nil
    private var downloadField: NSTextField? = nil
    
    private var publicIPField: NSTextField? = nil
    private var localIPField: NSTextField? = nil
    
    private var publicIPView: NSView? = nil
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.name)_base", defaultValue: "byte")) ?? .byte
    }
    private var speedUnit: String {
        networkSpeedUnit(from: Store.shared.string(key: "\(self.name)_speedUnit", defaultValue: NetworkSpeedUnitAuto)).key
    }
    private var reverseOrderState: Bool {
        Store.shared.bool(key: "\(self.name)_reverseOrder", defaultValue: false)
    }
    private var chartScale: Scale {
        Scale.fromString(Store.shared.string(key: "\(self.name)_chartScale", defaultValue: Scale.none.key))
    }
    private var chartFixedScale: Int {
        Store.shared.int(key: "\(self.name)_chartFixedScale", defaultValue: 12)
    }
    private var chartFixedScaleSize: SizeUnit {
        SizeUnit.fromString(Store.shared.string(key: "\(self.name)_chartFixedScaleSize", defaultValue: SizeUnit.MB.key))
    }
    private var publicIPState: Bool {
        Store.shared.bool(key: "\(self.name)_publicIP", defaultValue: true)
    }
    private var emojiCCState: Bool {
        Store.shared.bool(key: "\(self.name)_emojiCC", defaultValue: true)
    }
    
    private var downloadColor: NSColor {
        let v = SColor.fromString(Store.shared.string(key: "\(self.name)_downloadColor", defaultValue: SColor.secondBlue.key))
        var value = NSColor.systemBlue
        if let color = v.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColor: NSColor {
        let v = SColor.fromString(Store.shared.string(key: "\(self.name)_uploadColor", defaultValue: SColor.secondRed.key))
        var value = NSColor.systemRed
        if let color = v.additional as? NSColor {
            value = color
        }
        return value
    }
    
    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        self.body.alignment = .leading
        self.body.spacing = 9

        let speeds = self.ioView()
        speeds.heightAnchor.constraint(equalToConstant: 42).isActive = true
        let chart = self.chartView()
        chart.heightAnchor.constraint(equalToConstant: 58).isActive = true

        self.body.addArrangedSubview(speeds)
        speeds.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -(self.body.edgeInsets.left + self.body.edgeInsets.right)).isActive = true
        self.body.addArrangedSubview(chart)
        chart.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -(self.body.edgeInsets.left + self.body.edgeInsets.right)).isActive = true
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        CombinedPortalStyle.surface(view)
        
        let chart = CombinedHistoryBarsView(
            count: 18,
            firstColor: self.uploadColor,
            secondColor: self.downloadColor
        )
        self.chart = chart
        
        view.addArrangedSubview(chart)
        chart.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(view.edgeInsets.left + view.edgeInsets.right)).isActive = true
        
        return view
    }
    
    private func ioView() -> NSView {
        let view = NSStackView()
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = 18

        let upload = self.speedMetric(title: localizedString("Uploading"), color: self.uploadColor)
        self.uploadField = upload.field
        let download = self.speedMetric(title: localizedString("Downloading"), color: self.downloadColor)
        self.downloadField = download.field

        view.addArrangedSubview(upload.view)
        view.addArrangedSubview(download.view)
        return view
    }

    private func speedMetric(title: String, color: NSColor) -> (view: NSStackView, field: ValueField) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 1

        let value = ValueField("0 KB/s")
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        value.alignment = .center

        let label = NSStackView()
        label.orientation = .horizontal
        label.alignment = .centerY
        label.spacing = 5
        let marker = ColorBlock(color: color)
        marker.layer?.cornerRadius = 5
        let text = LabelField(title)
        text.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        text.textColor = color
        label.addArrangedSubview(marker)
        label.addArrangedSubview(text)

        stack.addArrangedSubview(value)
        stack.addArrangedSubview(label)
        return (stack, value)
    }
    
    private func detailsView() -> NSView {
        let view = combinedMetricStack(spacing: 3)
        self.localIPField = combinedDataRow(view, title: "\(localizedString("Local IP")):", value: localizedString("Unknown"), selectable: true)
        self.publicIPField = combinedDataRow(view, title: "\(localizedString("Public IP")):", value: localizedString("Unknown"), selectable: true)
        self.publicIPView = self.publicIPField?.superview
        self.publicIPView?.isHidden = !self.publicIPState
        return view
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            self.chart?.addValue(first: Double(value.bandwidth.upload), second: Double(value.bandwidth.download))
            
            guard (self.window?.isVisible ?? false) || !self.initialized else { return }
            self.initialized = true
            
            self.uploadField?.stringValue = Units(bytes: value.bandwidth.upload).getReadableSpeed(base: self.base, unit: self.speedUnit)
            self.downloadField?.stringValue = Units(bytes: value.bandwidth.download).getReadableSpeed(base: self.base, unit: self.speedUnit)
        })
    }
}

//
//  portal.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 16/03/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Portal: PortalWrapper {
    private let batteryView: BatteryView = BatteryView(showsPercentage: true, showsStatusBadge: true)
    
    private var chargeTimeField: NSTextField? = nil
    private var cyclesField: NSTextField? = nil
    private var capacityField: NSTextField? = nil
    
    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        self.body.alignment = .leading
        self.body.spacing = 6

        let top = NSStackView()
        top.orientation = .horizontal
        top.distribution = .fill
        top.alignment = .centerY
        top.spacing = 10
        top.heightAnchor.constraint(equalToConstant: 76).isActive = true

        let chart = self.chartView()
        chart.widthAnchor.constraint(equalToConstant: 126).isActive = true
        top.addArrangedSubview(chart)
        top.addArrangedSubview(self.summaryView())

        self.body.addArrangedSubview(top)
        top.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -(self.body.edgeInsets.left + self.body.edgeInsets.right)).isActive = true
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.edgeInsets = NSEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.addArrangedSubview(self.batteryView)
        return view
    }
    
    private func summaryView() -> NSView {
        let view = combinedMetricStack(spacing: 5)
        self.chargeTimeField = combinedDataRow(view, title: "\(localizedString("Time to full")):")
        self.cyclesField = combinedDataRow(view, title: "\(localizedString("Cycles")):")
        self.capacityField = combinedDataRow(view, title: "\(localizedString("Max capacity")):")
        self.capacityField?.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        return view
    }
    
    public func loadCallback(_ value: Battery_Usage) {
        DispatchQueue.main.async(execute: {
            self.batteryView.setValue(
                abs(value.level),
                connected: !value.isBatteryPowered,
                charging: value.isCharging,
                optimizedCharging: value.optimizedChargingEngaged,
                charged: value.isCharged
            )

            let chargeTime: String
            if value.isCharged || value.level >= 1 {
                chargeTime = localizedString("Fully charged")
            } else if value.optimizedChargingEngaged && !value.isCharging {
                chargeTime = localizedString("On hold")
            } else if value.isCharging && value.timeToCharge > 0 {
                chargeTime = Double(value.timeToCharge * 60).printSecondsToHoursMinutesSeconds(short: true)
            } else {
                chargeTime = "—"
            }
            self.chargeTimeField?.stringValue = chargeTime
            self.cyclesField?.stringValue = "\(value.cycles)"
            self.capacityField?.stringValue = "\(value.health)%"
            self.capacityField?.toolTip = "\(localizedString("Max capacity")): \(value.maxCapacity) mAh\n\(localizedString("Designed capacity")): \(value.designedCapacity) mAh"
        })
    }
}

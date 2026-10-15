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
        let chart = self.chartView()
        let details = self.detailsView()
        
        self.body.addArrangedSubview(chart)
        self.body.addArrangedSubview(details)
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.addArrangedSubview(self.batteryView)
        return view
    }
    
    private func detailsView() -> NSView {
        let view = NSStackView()
        
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        self.chargeTimeField = portalRow(view, title: "\(localizedString("Time to full")):").1
        self.cyclesField = portalRow(view, title: "\(localizedString("Cycles")):").1
        self.capacityField = portalRow(view, title: "\(localizedString("Max capacity")):").1
        
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
            self.capacityField?.stringValue = "\(value.health)% · \(value.maxCapacity) mAh"
            self.capacityField?.toolTip = "\(localizedString("Designed capacity")): \(value.designedCapacity) mAh"
        })
    }
}

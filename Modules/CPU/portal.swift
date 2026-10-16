//
//  portal.swift
//  CPU
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
    private var historyChart: CombinedHistoryBarsView? = nil
    private var userField: NSTextField? = nil
    private var systemField: NSTextField? = nil
    private var initialized: Bool = false

    private var systemColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_systemColor", defaultValue: SColor.secondRed.key)).additional as! NSColor
    }
    private var userColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_userColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }

    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        self.body.spacing = 7

        let chart = CombinedHistoryBarsView(
            count: 40,
            firstColor: self.userColor,
            secondColor: self.systemColor,
            stacked: true,
            fixedMaximum: 1
        )
        chart.heightAnchor.constraint(equalToConstant: 58).isActive = true
        self.historyChart = chart
        self.body.addArrangedSubview(chart)

        let metrics = NSStackView()
        metrics.orientation = .horizontal
        metrics.distribution = .fillEqually
        metrics.spacing = 18
        metrics.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let user = combinedMetricStack(spacing: 1)
        self.userField = combinedDataRow(user, title: localizedString("User"), color: self.userColor)
        self.userField?.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)

        let system = combinedMetricStack(spacing: 1)
        self.systemField = combinedDataRow(system, title: localizedString("System"), color: self.systemColor)
        self.systemField?.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)

        metrics.addArrangedSubview(user)
        metrics.addArrangedSubview(system)
        self.body.addArrangedSubview(metrics)
    }

    internal func callback(_ value: CPU_Load) {
        DispatchQueue.main.async {
            self.historyChart?.addValue(first: value.userLoad, second: value.systemLoad)
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
                self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
                self.initialized = true
            }
        }
    }
}

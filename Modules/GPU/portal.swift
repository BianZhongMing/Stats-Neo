//
//  portal.swift
//  GPU
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
    private var circle: PieChartView = PieChartView(drawValue: true)
    
    private var usageField: NSTextField? = nil
    private var aneField: NSTextField? = nil
    private var fpsField: NSTextField? = nil
    
    private var initialized: Bool = false
    
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
        let view = combinedMetricStack(spacing: 6)
        self.usageField = combinedDataRow(view, title: "\(localizedString("Usage")):")
        self.aneField = combinedDataRow(view, title: "ANE:")
        self.fpsField = combinedDataRow(view, title: "FPS:")
        return view
    }
    
    internal func callback(_ value: GPU_Info) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                if let value = value.utilization {
                    self.usageField?.stringValue = "\(Int(value*100))%"
                }
                if let value = value.aneUtilization {
                    self.aneField?.stringValue = "\(Int(value*100))%"
                }
                if let value = value.fps {
                    self.fpsField?.stringValue = "\(Int(value.rounded()))"
                }
                
                self.circle.toolTip = "\(localizedString("GPU utilization")): \(Int(value.utilization!*100))%"
                self.circle.setValue(value.utilization!)
                
                self.initialized = true
            }
        })
    }
}

//
//  Repeater.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 27/06/2022.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

private enum RepeaterState {
    case paused
    case running
}

/// Coalesces readers with the same interval onto one timer while executing callbacks
/// on a separate utility queue so a callback can safely change its own interval.
private final class RepeaterCoordinator {
    static let shared = RepeaterCoordinator()

    private final class Bucket {
        let timer: DispatchSourceTimer
        var handlers: [UUID: () -> Void] = [:]

        init(interval: Int, queue: DispatchQueue, callbackQueue: DispatchQueue) {
            self.timer = DispatchSource.makeTimerSource(queue: queue)
            let leeway = min(max(interval * 100, 200), 1_000)
            self.timer.schedule(
                deadline: .now() + .seconds(interval),
                repeating: .seconds(interval),
                leeway: .milliseconds(leeway)
            )
            self.timer.setEventHandler { [weak self] in
                guard let self else { return }
                let callbacks = Array(self.handlers.values)
                callbacks.forEach { callback in
                    callbackQueue.async(execute: callback)
                }
            }
            self.timer.resume()
        }

        deinit {
            self.timer.setEventHandler {}
            self.timer.cancel()
        }
    }

    private struct BucketKey: Hashable {
        let interval: Int
        let group: Int
    }

    private let queue = DispatchQueue(label: "eu.exelban.Stats.Repeater.coordinator", qos: .utility)
    private let callbackQueue = DispatchQueue(label: "eu.exelban.Stats.Repeater.callbacks", qos: .utility, attributes: .concurrent)
    private var buckets: [BucketKey: Bucket] = [:]

    func add(interval: Int, group: Int, id: UUID, callback: @escaping () -> Void) {
        self.queue.sync {
            let key = BucketKey(interval: max(1, interval), group: group)
            let bucket: Bucket
            if let existing = self.buckets[key] {
                bucket = existing
            } else {
                let created = Bucket(interval: key.interval, queue: self.queue, callbackQueue: self.callbackQueue)
                self.buckets[key] = created
                bucket = created
            }
            bucket.handlers[id] = callback
        }
    }

    func remove(interval: Int, group: Int, id: UUID) {
        self.queue.sync {
            let key = BucketKey(interval: max(1, interval), group: group)
            guard let bucket = self.buckets[key] else { return }
            bucket.handlers.removeValue(forKey: id)
            if bucket.handlers.isEmpty {
                self.buckets.removeValue(forKey: key)
            }
        }
    }
}

internal final class Repeater {
    private let id = UUID()
    private var callback: () -> Void
    private var state: RepeaterState = .paused
    private var interval: Int
    private let group: Int

    internal init(seconds: Int, group: Int = 0, callback: @escaping () -> Void) {
        self.interval = max(1, seconds)
        self.group = group
        self.callback = callback
    }

    deinit {
        self.pause()
    }

    internal func start() {
        guard self.state == .paused else { return }
        RepeaterCoordinator.shared.add(interval: self.interval, group: self.group, id: self.id, callback: self.callback)
        self.state = .running
    }

    internal func pause() {
        guard self.state == .running else { return }
        RepeaterCoordinator.shared.remove(interval: self.interval, group: self.group, id: self.id)
        self.state = .paused
    }

    internal func reset(seconds: Int, restart: Bool = false) {
        let wasRunning = self.state == .running
        if wasRunning { self.pause() }
        self.interval = max(1, seconds)
        if restart || wasRunning {
            DispatchQueue.global(qos: .utility).async(execute: self.callback)
            self.start()
        }
    }
}

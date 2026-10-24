import CoreData
import Foundation
import SwiftData

/// `NotificationCenter` observer closures are `@Sendable`, but a `@MainActor` object isn't `Sendable`.
/// The box is, and its weak reference is only ever read back on the main actor.
final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

/// Reacts to CloudKit imports: debounces bursts of `NSPersistentStoreRemoteChange`, then runs an
/// idempotent refresh (dedupe) that only saves when something changed. Not saving when nothing changed
/// is what stops the refresh from triggering its own next remote-change notification.
@MainActor
final class SyncRefresher {
    private let context: ModelContext
    private let debounce: Duration
    private let center: NotificationCenter
    private let notificationName: Notification.Name
    private var observer: NSObjectProtocol?
    private var pending: Task<Void, Never>?

    /// Number of completed refresh runs (for tests/diagnostics).
    private(set) var refreshCount = 0
    private(set) var lastReport = Deduplicator.Report()

    init(context: ModelContext,
         debounce: Duration = .milliseconds(500),
         center: NotificationCenter = .default,
         notificationName: Notification.Name = .NSPersistentStoreRemoteChange) {
        self.context = context
        self.debounce = debounce
        self.center = center
        self.notificationName = notificationName
    }

    func start() {
        guard observer == nil else { return }
        let box = WeakBox(self)
        observer = center.addObserver(forName: notificationName, object: nil, queue: nil) { _ in
            Task { @MainActor in box.value?.scheduleRefresh() }
        }
    }

    func stop() {
        if let observer { center.removeObserver(observer) }
        observer = nil
        pending?.cancel()
        pending = nil
    }

    /// Restarts the debounce window; only the last call in a burst runs.
    func scheduleRefresh() {
        pending?.cancel()
        let delay = debounce
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Dedupes and saves only if there are changes. Safe to call any time (e.g. on foreground).
    /// Returns true if it saved.
    @discardableResult
    func refresh() -> Bool {
        defer { refreshCount += 1 }
        do {
            lastReport = try Deduplicator.run(in: context)
            guard context.hasChanges else { return false }
            try context.save()
            return true
        } catch {
            return false
        }
    }
}

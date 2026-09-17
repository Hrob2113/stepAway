import AppKit
import CoreGraphics
import Observation
import UserNotifications

enum BreakKind {
    case short, long

    var title: String { self == .short ? "Look into the distance" : "Take a longer break" }

    var guidance: String {
        self == .short
            ? "Rest your eyes on something about 20 feet away."
            : "Stand up, stretch, and let your eyes wander."
    }
}

enum Phase: Equatable {
    case working
    case resting(BreakKind)
    case paused(until: Date?)

    static func == (a: Phase, b: Phase) -> Bool {
        switch (a, b) {
        case (.working, .working): true
        case let (.resting(x), .resting(y)): x == y
        case let (.paused(x), .paused(y)): x == y
        default: false
        }
    }
}

enum MicroReminder: String, Identifiable {
    case posture, blink
    var id: String { rawValue }
}

@Observable
final class BreakManager {
    private(set) var phase: Phase = .working
    private(set) var completedBreaks = 0
    private(set) var shortBreaksSinceLong = 0
    private(set) var activeMicroReminder: MicroReminder?
    private(set) var showIdleReturn = false

    private(set) var now = Date()

    private let settings: AppSettings
    private var deadline = Date()
    private var ticker: Task<Void, Never>?
    private var lastTick = Date()
    private var warningSent = false

    private var nextPosture = Date.distantFuture
    private var nextBlink = Date.distantFuture
    private var microExpiry = Date.distantFuture

    private let awayThreshold: TimeInterval = 5 * 60
    private var awaySince: Date?

    init(settings: AppSettings) {
        self.settings = settings
        beginWork()
        start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: - Derived state

    var timeRemaining: TimeInterval {
        switch phase {
        case .paused(let until): until.map { max(0, $0.timeIntervalSince(now)) } ?? 0
        default: max(0, deadline.timeIntervalSince(now))
        }
    }

    var progress: Double {
        let total = switch phase {
        case .working: settings.workDuration
        case .resting(let kind): duration(of: kind)
        case .paused: 0.0
        }
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - timeRemaining / total))
    }

    var isResting: Bool { if case .resting = phase { true } else { false } }
    var isPaused: Bool { if case .paused = phase { true } else { false } }

    var menuBarText: String {
        switch phase {
        case .working: timeRemaining.clockText
        case .resting: "Resting"
        case .paused: "Paused"
        }
    }

    var statusHeadline: String {
        switch phase {
        case .working: "Next break in \(timeRemaining.casualText)"
        case .resting(let kind): kind == .short ? "Short break in progress" : "Long break in progress"
        case .paused(let until):
            if let until { "Paused for \(max(0, until.timeIntervalSince(now)).casualText)" }
            else { "Paused until tomorrow" }
        }
    }

    var cycleProgress: String {
        let n = settings.breaksBeforeLong
        guard n > 0 else { return "" }
        if nextBreakIsLong { return "A long break is next" }
        let remaining = max(1, n - shortBreaksSinceLong)
        return remaining == 1
            ? "Long break after the next one"
            : "\(remaining) short breaks until a long one"
    }

    private var nextBreakIsLong: Bool {
        settings.breaksBeforeLong > 0 && shortBreaksSinceLong >= settings.breaksBeforeLong
    }

    // MARK: - Commands

    func startBreak() {
        beginRest(nextBreakIsLong ? .long : .short)
    }

    func endBreak() {
        if case .resting(let kind) = phase { recordBreak(long: kind == .long) }
        play("Tink")
        beginWork()
    }

    func skipBreak() {
        guard settings.allowSkip else { return }
        if case .resting(let kind) = phase {
            recordBreak(long: kind == .long)
        } else {
            recordBreak(long: nextBreakIsLong)
        }
        beginWork()
    }

    private func recordBreak(long: Bool) {
        completedBreaks += 1
        shortBreaksSinceLong = long ? 0 : shortBreaksSinceLong + 1
    }

    func restartBreak() {
        if case .resting(let kind) = phase { beginRest(kind) }
    }

    func resetTimer() { beginWork() }

    func startFreshSession() {
        completedBreaks = 0
        shortBreaksSinceLong = 0
        beginWork()
    }

    func pause(for interval: TimeInterval) {
        phase = .paused(until: Date().addingTimeInterval(interval))
        clearMicroReminders()
    }

    func pauseUntilTomorrow() {
        phase = .paused(until: nil)
        clearMicroReminders()
    }

    func resume() { beginWork() }

    func dismissIdleReturn() { showIdleReturn = false }

    func creditIdleBreak() {
        showIdleReturn = false
        recordBreak(long: nextBreakIsLong)
        beginWork()
    }

    func dismissMicroReminder() {
        activeMicroReminder = nil
        microExpiry = .distantFuture
    }

    // MARK: - Phases

    private func duration(of kind: BreakKind) -> TimeInterval {
        kind == .short ? settings.shortBreakDuration : settings.longBreakDuration
    }

    private func beginWork() {
        phase = .working
        deadline = Date().addingTimeInterval(settings.workDuration)
        warningSent = false
        scheduleMicroReminders()
    }

    private func beginRest(_ kind: BreakKind) {
        phase = .resting(kind)
        deadline = Date().addingTimeInterval(duration(of: kind))
        play("Submarine")
        clearMicroReminders()
    }

    private func scheduleMicroReminders() {
        nextPosture = settings.postureRemindersOn
            ? Date().addingTimeInterval(settings.postureInterval) : .distantFuture
        nextBlink = settings.blinkRemindersOn
            ? Date().addingTimeInterval(settings.blinkInterval) : .distantFuture
    }

    private func clearMicroReminders() {
        activeMicroReminder = nil
        microExpiry = .distantFuture
        nextPosture = .distantFuture
        nextBlink = .distantFuture
    }

    // MARK: - Tick

    private func start() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        let current = Date()
        let delta = max(0, current.timeIntervalSince(lastTick))
        lastTick = current
        now = current

        if current >= microExpiry { dismissMicroReminder() }

        switch phase {
        case .working:
            if handleIdle(delta: delta, at: current) { return }
            sendWarningIfDue(at: current)
            if current >= deadline { startBreak() } else { fireMicroReminderIfDue(at: current) }

        case .resting:
            if current >= deadline { endBreak() }

        case .paused(let until):
            if let until, current >= until { resume() }
        }
    }

    private func handleIdle(delta: TimeInterval, at current: Date) -> Bool {
        let idle = Self.systemIdleTime()

        guard idle >= awayThreshold else {
            if let since = awaySince {
                awaySince = nil
                if current.timeIntervalSince(since) >= awayThreshold { showIdleReturn = true }
            }
            return false
        }

        if awaySince == nil { awaySince = current.addingTimeInterval(-idle) }
        deadline = deadline.addingTimeInterval(delta)
        return true
    }

    private static func systemIdleTime() -> TimeInterval {
        guard let any = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: any)
    }

    private func fireMicroReminderIfDue(at current: Date) {
        guard activeMicroReminder == nil else { return }

        if settings.postureRemindersOn, current >= nextPosture {
            activeMicroReminder = .posture
            nextPosture = current.addingTimeInterval(settings.postureInterval)
        } else if settings.blinkRemindersOn, current >= nextBlink {
            activeMicroReminder = .blink
            nextBlink = current.addingTimeInterval(settings.blinkInterval)
        } else {
            return
        }
        microExpiry = current.addingTimeInterval(5)
    }

    private func sendWarningIfDue(at current: Date) {
        guard !warningSent, settings.preBreakWarning > 0 else { return }
        guard deadline.timeIntervalSince(current) <= settings.preBreakWarning else { return }
        warningSent = true

        let content = UNMutableNotificationContent()
        content.title = "Break coming up"
        content.body = "Your eyes get a rest in \(settings.preBreakWarning.casualText)."
        if settings.soundEnabled { content.sound = .default }

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "stepaway.prebreak", content: content, trigger: nil)
        )
    }

    private func play(_ name: String) {
        guard settings.soundEnabled else { return }
        NSSound(named: name)?.play()
    }
}

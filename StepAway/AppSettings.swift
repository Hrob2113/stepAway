import Foundation
import Observation

enum Preset: String, CaseIterable, Identifiable {
    case balanced, relaxed, intensive, custom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .balanced:  "Balanced"
        case .relaxed:   "Relaxed"
        case .intensive: "Intensive"
        case .custom:    "Custom"
        }
    }

    var detail: String {
        switch self {
        case .balanced:  "20 minutes of work, then a short look away"
        case .relaxed:   "Longer stretches, longer rests"
        case .intensive: "Frequent breaks for heavy screen days"
        case .custom:    "Your own intervals, set in Timers"
        }
    }

    var schedule: Schedule? {
        switch self {
        case .balanced:  Schedule(work: 20 * 60, short: 30, long: 5 * 60, beforeLong: 4)
        case .relaxed:   Schedule(work: 30 * 60, short: 45, long: 8 * 60, beforeLong: 3)
        case .intensive: Schedule(work: 15 * 60, short: 25, long: 4 * 60, beforeLong: 4)
        case .custom:    nil
        }
    }

    struct Schedule {
        let work: TimeInterval
        let short: TimeInterval
        let long: TimeInterval
        let beforeLong: Int
    }
}

@Observable
final class AppSettings {
    var workDuration: TimeInterval       { didSet { write(workDuration, .workDuration);       demoteToCustom(oldValue != workDuration) } }
    var shortBreakDuration: TimeInterval { didSet { write(shortBreakDuration, .shortBreak);   demoteToCustom(oldValue != shortBreakDuration) } }
    var longBreakDuration: TimeInterval  { didSet { write(longBreakDuration, .longBreak);     demoteToCustom(oldValue != longBreakDuration) } }
    var breaksBeforeLong: Int            { didSet { write(breaksBeforeLong, .breaksBeforeLong); demoteToCustom(oldValue != breaksBeforeLong) } }

    var allowSkip: Bool                  { didSet { write(allowSkip, .allowSkip) } }
    var soundEnabled: Bool               { didSet { write(soundEnabled, .soundEnabled) } }
    var preBreakWarning: TimeInterval    { didSet { write(preBreakWarning, .preBreakWarning) } }

    var postureRemindersOn: Bool         { didSet { write(postureRemindersOn, .postureOn) } }
    var postureInterval: TimeInterval     { didSet { write(postureInterval, .postureInterval) } }
    var blinkRemindersOn: Bool           { didSet { write(blinkRemindersOn, .blinkOn) } }
    var blinkInterval: TimeInterval       { didSet { write(blinkInterval, .blinkInterval) } }

    private(set) var preset: Preset      { didSet { write(preset.rawValue, .preset) } }

    private var isApplyingPreset = false

    init() {
        let d = UserDefaults.standard
        let stored = Preset(rawValue: d.string(forKey: Key.preset.rawValue) ?? "") ?? .balanced
        let base = stored.schedule ?? Preset.balanced.schedule!

        preset             = stored
        workDuration       = d.value(forKey: Key.workDuration.rawValue) as? TimeInterval ?? base.work
        shortBreakDuration = d.value(forKey: Key.shortBreak.rawValue) as? TimeInterval ?? base.short
        longBreakDuration  = d.value(forKey: Key.longBreak.rawValue) as? TimeInterval ?? base.long
        breaksBeforeLong   = d.value(forKey: Key.breaksBeforeLong.rawValue) as? Int ?? base.beforeLong

        allowSkip          = d.value(forKey: Key.allowSkip.rawValue) as? Bool ?? true
        soundEnabled       = d.value(forKey: Key.soundEnabled.rawValue) as? Bool ?? true
        preBreakWarning    = d.value(forKey: Key.preBreakWarning.rawValue) as? TimeInterval ?? 30

        postureRemindersOn = d.value(forKey: Key.postureOn.rawValue) as? Bool ?? true
        postureInterval    = d.value(forKey: Key.postureInterval.rawValue) as? TimeInterval ?? 10 * 60
        blinkRemindersOn   = d.value(forKey: Key.blinkOn.rawValue) as? Bool ?? true
        blinkInterval      = d.value(forKey: Key.blinkInterval.rawValue) as? TimeInterval ?? 20 * 60
    }

    func apply(_ preset: Preset) {
        guard let schedule = preset.schedule else {
            self.preset = .custom
            return
        }
        isApplyingPreset = true
        workDuration       = schedule.work
        shortBreakDuration = schedule.short
        longBreakDuration  = schedule.long
        breaksBeforeLong   = schedule.beforeLong
        isApplyingPreset = false
        self.preset = preset
    }

    private func demoteToCustom(_ didChange: Bool) {
        guard didChange, !isApplyingPreset, preset != .custom else { return }
        preset = .custom
    }

    private enum Key: String {
        case workDuration, shortBreak, longBreak, breaksBeforeLong
        case allowSkip, soundEnabled, preBreakWarning
        case postureOn, postureInterval, blinkOn, blinkInterval
        case preset
    }

    private func write(_ value: Any, _ key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}

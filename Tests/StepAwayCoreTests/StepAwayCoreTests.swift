import CoreText
import Foundation
import Testing

@testable import StepAwayCore

// MARK: - Formatting

@Suite("Durations read the way a person would say them")
struct DurationText {
    @Test func secondsStayLoose() {
        #expect(TimeInterval(45).clockText == "45s")
        #expect(TimeInterval(0).clockText == "0s")
    }

    @Test func aMinuteSwitchesToAClock() {
        #expect(TimeInterval(90).clockText == "1:30")
        #expect(TimeInterval(1200).clockText == "20:00")
    }

    @Test func negativesFloorAtZero() {
        #expect(TimeInterval(-12).clockText == "0s")
        #expect(TimeInterval(-12).casualText == "0 sec")
    }

    @Test func casualTextPicksTheLargestUnit() {
        #expect(TimeInterval(30).casualText == "30 sec")
        #expect(TimeInterval(1200).casualText == "20 min")
        #expect(TimeInterval(7200).casualText == "2 hr")
    }
}

// MARK: - Settings

@Suite("Presets own the timers until you edit one")
struct Presets {
    @Test func applyingAPresetSetsItsSchedule() {
        let settings = AppSettings()
        settings.apply(.relaxed)
        #expect(settings.preset == .relaxed)
        #expect(settings.workDuration == 30 * 60)
        settings.apply(.balanced)
    }

    @Test func editingATimerDemotesToCustom() {
        let settings = AppSettings()
        settings.apply(.balanced)
        settings.workDuration = 1500
        #expect(settings.preset == .custom)
        settings.apply(.balanced)
        #expect(settings.preset == .balanced)
        #expect(settings.workDuration == 20 * 60)
    }

    @Test func everyNamedPresetCarriesASchedule() {
        for preset in Preset.allCases where preset != .custom {
            #expect(preset.schedule != nil, "\(preset.name) has no schedule")
        }
        #expect(Preset.custom.schedule == nil)
    }
}

// MARK: - Break engine

@Suite("The long break lands on the right beat")
struct Cadence {
    private func balanced() -> AppSettings {
        let settings = AppSettings()
        settings.apply(.balanced)
        return settings
    }

    @Test func longBreakArrivesAfterEveryFourShortOnes() {
        let manager = BreakManager(settings: balanced())
        var pattern = ""
        for _ in 0..<10 {
            manager.startBreak()
            pattern += manager.phase == .resting(.long) ? "L" : "s"
            manager.endBreak()
        }
        #expect(pattern == "ssssLssssL")
    }

    @Test func theLongBreakDoesNotEatAShortSlot() {
        let settings = balanced()
        settings.breaksBeforeLong = 2
        let manager = BreakManager(settings: settings)
        var pattern = ""
        for _ in 0..<9 {
            manager.startBreak()
            pattern += manager.phase == .resting(.long) ? "L" : "s"
            manager.endBreak()
        }
        #expect(pattern == "ssLssLssL")
    }

    @Test func cycleCopyCountsDownToTheLongBreak() {
        let manager = BreakManager(settings: balanced())
        #expect(manager.cycleProgress == "4 short breaks until a long one")
        for _ in 0..<3 {
            manager.startBreak()
            manager.endBreak()
        }
        #expect(manager.cycleProgress == "Long break after the next one")
        manager.startBreak()
        manager.endBreak()
        #expect(manager.cycleProgress == "A long break is next")
    }
}

@Suite("Phases move only where they should")
struct Phases {
    private func manager() -> BreakManager {
        let settings = AppSettings()
        settings.apply(.balanced)
        return BreakManager(settings: settings)
    }

    @Test func pauseAndResume() {
        let manager = manager()
        manager.pause(for: 1800)
        #expect(manager.isPaused)
        #expect(!manager.isResting)
        manager.resume()
        #expect(!manager.isPaused)
        #expect(manager.phase == .working)
    }

    @Test func restingIsEnteredAndLeft() {
        let manager = manager()
        #expect(!manager.isResting)
        manager.startBreak()
        #expect(manager.isResting)
        manager.endBreak()
        #expect(manager.phase == .working)
    }

    @Test func aFreshSessionReturnsToWork() {
        let manager = manager()
        manager.startBreak()
        manager.startFreshSession()
        #expect(manager.phase == .working)
    }

    @Test func theMenuBarSaysWhatThePhaseIs() {
        let manager = manager()
        manager.startBreak()
        #expect(manager.menuBarText == "Resting")
        manager.endBreak()
        manager.pause(for: 600)
        #expect(manager.menuBarText == "Paused")
        manager.resume()
        #expect(manager.menuBarText.contains(":") || manager.menuBarText.hasSuffix("s"))
    }
}

// MARK: - Typography

@Suite("Every face the theme asks for is actually bundled")
struct Faces {
    private static let fonts: URL = {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "StepAway/Fonts")
    }()

    private static let registered: Bool = {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: fonts, includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "ttf" } ?? []
        guard !urls.isEmpty else { return false }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
        return true
    }()

    @Test func eachFaceHasAFile() {
        for face in Theme.Face.allCases {
            let file = Self.fonts.appending(path: "\(face.rawValue).ttf")
            #expect(
                FileManager.default.fileExists(atPath: file.path),
                "\(face.rawValue).ttf is referenced by Theme but not bundled"
            )
        }
    }

    @Test func eachFaceResolvesRatherThanFallingBack() {
        #expect(Self.registered)
        for face in Theme.Face.allCases {
            let font = CTFontCreateWithName(face.rawValue as CFString, 20, nil)
            let resolved = CTFontCopyPostScriptName(font) as String
            #expect(resolved == face.rawValue, "\(face.rawValue) fell back to \(resolved)")
        }
    }

    @Test func theCounterFaceHasFixedWidthDigits() {
        #expect(Self.registered)
        let font = CTFontCreateWithName(Theme.Face.label.rawValue as CFString, 40, nil)
        let widths = Set("0123456789".map { character -> Int in
            var glyph = CGGlyph(0)
            var scalars = Array(String(character).utf16)
            CTFontGetGlyphsForCharacters(font, &scalars, &glyph, 1)
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
            return Int((advance.width * 100).rounded())
        })
        #expect(widths.count == 1, "a countdown set in this face would wobble")
    }

    @Test func noFontIsBundledWithoutBeingUsed() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: Self.fonts, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "ttf" }
            .map { $0.deletingPathExtension().lastPathComponent }
        let wanted = Set(Theme.Face.allCases.map(\.rawValue))
        #expect(Set(files) == wanted, "bundled fonts and theme faces have drifted apart")
    }
}

// MARK: - Eye

@Suite("The eye's lid profile is a well-formed almond")
struct LidGeometry {
    @Test func itClosesAtBothCorners() {
        #expect(EyeGlyph.lidRatio(-1) == 0)
        #expect(EyeGlyph.lidRatio(1) == 0)
        #expect(EyeGlyph.lidRatio(-1.4) == 0)
        #expect(EyeGlyph.lidRatio(2) == 0)
    }

    @Test func itIsWidestAtTheCentre() {
        #expect(EyeGlyph.lidRatio(0) == 1)
    }

    @Test func itIsSymmetric() {
        for step in 1...20 {
            let u = CGFloat(step) / 21
            #expect(abs(EyeGlyph.lidRatio(u) - EyeGlyph.lidRatio(-u)) < 0.0001)
        }
    }

    @Test func itNarrowsMonotonicallyTowardTheCorner() {
        var previous = EyeGlyph.lidRatio(0)
        for step in 1...40 {
            let ratio = EyeGlyph.lidRatio(CGFloat(step) / 41)
            #expect(ratio <= previous)
            previous = ratio
        }
    }
}

@Suite("Blinking happens on its own schedule")
struct Blink {
    @Test func theEyeIsOpenBetweenBlinks() {
        let eye = EyeGlyph()
        #expect(eye.openness(at: 2.0) == 1)
        #expect(eye.openness(at: 4.9) == 1)
    }

    @Test func theEyeShutsDuringOne() {
        #expect(EyeGlyph().openness(at: 0.1444) < 0.1)
    }

    @Test func aStillEyeNeverBlinks() {
        let eye = EyeGlyph(animated: false)
        for step in 0...52 {
            #expect(eye.openness(at: Double(step) / 10) == 1)
        }
    }
}

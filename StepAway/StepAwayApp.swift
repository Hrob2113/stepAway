import SwiftUI
import UserNotifications

@MainActor
final class AppModel {
    let settings = AppSettings()
    let manager: BreakManager
    let presenter: OverlayPresenter

    init() {
        manager = BreakManager(settings: settings)
        presenter = OverlayPresenter(manager: manager, settings: settings)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSApp.appearance = NSAppearance(named: .darkAqua)

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

@main
struct StepAwayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(manager: model.manager, settings: model.settings)
        } label: {
            Image(systemName: model.manager.menuBarIcon)
            Text(model.manager.menuBarText)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: model.settings, manager: model.manager)
        }
    }
}

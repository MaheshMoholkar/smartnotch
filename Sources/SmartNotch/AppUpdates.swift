import AppKit
import Observation
#if canImport(Sparkle)
import Sparkle
#endif

/// Sparkle owns download validation, replacement, relaunch and its update UI.
/// Application termination still goes through AppDelegate, which saves the session.
@Observable
final class AppUpdates: NSObject {
    private(set) var availableVersion: String?
    private(set) var canCheck = true
    var updateAvailable: Bool { availableVersion != nil }

    #if canImport(Sparkle)
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var checkObservation: NSKeyValueObservation?
    private static let versionKey = "SmartNotchAvailableUpdateVersion"
    private static let buildKey = "SmartNotchAvailableUpdateBuild"
    #endif

    func start() {
        guard ProcessInfo.processInfo.environment["SMARTNOTCH_SESSION_PATH"] == nil,
              Self.isConfigured(Bundle.main.infoDictionary ?? [:]) else { return }
        #if canImport(Sparkle)
        let defaults = UserDefaults.standard
        if let cachedBuild = defaults.string(forKey: Self.buildKey),
           let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           cachedBuild.compare(currentBuild, options: .numeric) == .orderedDescending {
            recordAvailableVersion(defaults.string(forKey: Self.versionKey))
        } else {
            defaults.removeObject(forKey: Self.versionKey)
            defaults.removeObject(forKey: Self.buildKey)
        }
        let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        controller = updater
        checkObservation = updater.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
        }
        updater.startUpdater()
        #endif
    }

    static func isConfigured(_ info: [String: Any]) -> Bool {
        guard let feed = info["SUFeedURL"] as? String,
              let url = URL(string: feed), url.scheme == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              let key = info["SUPublicEDKey"] as? String,
              Data(base64Encoded: key)?.count == 32 else { return false }
        return true
    }

    var automaticallyChecks: Bool {
        get {
            #if canImport(Sparkle)
            controller?.updater.automaticallyChecksForUpdates ?? false
            #else
            false
            #endif
        }
        set {
            #if canImport(Sparkle)
            controller?.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }

    /// Keep an announcement until a successful check says no update is available.
    /// A failed request or dismissed update window must not hide a known update.
    func recordAvailableVersion(_ version: String?) {
        availableVersion = version
    }

    var isAvailable: Bool {
        #if canImport(Sparkle)
        controller != nil
        #else
        false
        #endif
    }

    func check() {
        #if canImport(Sparkle)
        if let controller {
            guard controller.updater.canCheckForUpdates else { return }
            NSApp.activate(ignoringOtherApps: true)
            controller.checkForUpdates(nil)
            return
        }
        #endif
        let alert = NSAlert()
        alert.messageText = "Updates aren’t available in this build"
        alert.informativeText = "Install a release of SmartNotch with updates enabled to receive future updates in the app. Your saved content stays on this computer."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

#if canImport(Sparkle)
extension AppUpdates: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        UserDefaults.standard.set(item.displayVersionString, forKey: Self.versionKey)
        UserDefaults.standard.set(item.versionString, forKey: Self.buildKey)
        recordAvailableVersion(item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        UserDefaults.standard.removeObject(forKey: Self.versionKey)
        UserDefaults.standard.removeObject(forKey: Self.buildKey)
        recordAvailableVersion(nil)
    }
}
#endif

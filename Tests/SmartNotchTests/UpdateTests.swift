import Foundation
import AppKit
import SwiftUI
import Observation
import Testing
@testable import SmartNotch

@Test @MainActor func updateBadgeObservesDetectionAndSurvivesWorkspaceChanges() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/session.json"))
    #expect(!model.updates.updateAvailable)
    var notified = false
    withObservationTracking {
        _ = model.updates.updateAvailable
    } onChange: {
        MainActor.assumeIsolated { notified = true }
    }
    model.updates.recordAvailableVersion("0.2.1")
    #expect(notified)
    #expect(model.updates.updateAvailable)
    #expect(model.updates.availableVersion == "0.2.1")
    model.activeTab = .cards
    model.isExpanded = false
    model.activeTab = .notes
    model.isExpanded = true
    #expect(model.updates.updateAvailable)
    model.updates.recordAvailableVersion(nil)
    #expect(!model.updates.updateAvailable)
}

@Test @MainActor func updateBadgeFitsPopupWidths() throws {
    _ = NSApplication.shared
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/session.json"))
    model.updates.recordAvailableVersion("0.2.1")
    for width in [420.0, 580.0, 680.0] {
        let host = NSHostingView(rootView: PanelView(model: model, hide: {}, isPreview: true)
            .frame(width: width, height: 400))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 400)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width <= width)
        if let directory = ProcessInfo.processInfo.environment["SMARTNOTCH_UPDATE_SNAPSHOT_DIR"],
           let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to:
                URL(filePath: directory).appendingPathComponent("update-panel-\(Int(width)).png"))
        }
    }
}

@Test @MainActor func updaterRequiresHTTPSAndValidSigningKey() {
    let key = Data(repeating: 1, count: 32).base64EncodedString()
    #expect(AppUpdates.isConfigured(["SUFeedURL": "https://updates.example.com/mac/appcast.xml", "SUPublicEDKey": key]))
    for feed in ["http://updates.example.com/mac/appcast.xml", "file:///tmp/appcast.xml", "https://user:password@updates.example.com/feed", "https://"] {
        #expect(!AppUpdates.isConfigured(["SUFeedURL": feed, "SUPublicEDKey": key]))
    }
    #expect(!AppUpdates.isConfigured(["SUFeedURL": "https://updates.example.com/feed", "SUPublicEDKey": "invalid"]))
    #expect(!AppUpdates.isConfigured([:]))
}

@Test @MainActor func failedSavePreventsUpdateRestart() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/session.json"))
    model.notes = "Unsaved notes"
    #expect(!model.save())
    #expect(model.errorMessage != nil)
}

@Test @MainActor func savedContentSurvivesUpdateRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("session.json")
    let model = PromptModel(saveURL: file)
    model.text = "My recording script"
    model.activeTab = .notes
    model.notes = "Notes kept across app replacement"
    #expect(model.save())
    let reopened = PromptModel(saveURL: file)
    #expect(reopened.notes == "Notes kept across app replacement")
    reopened.activeTab = .read
    #expect(reopened.text == "My recording script")
}

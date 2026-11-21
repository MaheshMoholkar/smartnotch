import Foundation
import AppKit
import SwiftUI
import Testing
@testable import SmartNotch

@Test @MainActor func readPlaybackAndMicrophoneDoNotStartInCardsOrNotes() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = "Read this aloud."
    model.mode = .voice
    var microphoneStarts = 0
    model.onVoiceStart = { microphoneStarts += 1 }
    model.activeTab = .cards
    model.addCard()
    model.cardTitle = "A point"
    model.togglePlayback()
    #expect(microphoneStarts == 0)
    #expect(!model.isStartingVoice)
    #expect(!model.isPlaying)
    model.activeTab = .notes
    model.notes = "Notes can be opened without starting recognition."
    model.togglePlayback()
    #expect(microphoneStarts == 0)
    #expect(!model.isStartingVoice)
    #expect(!model.isPlaying)
    model.activeTab = .read
    model.togglePlayback()
    #expect(microphoneStarts == 1)
    #expect(model.isStartingVoice)
    model.pause()
}

@Test @MainActor func nativePopupNotesEditorAcceptsTypingAndEscapeFinishesEditing() async throws {
    _ = NSApplication.shared
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.activeTab = .notes
    model.notes = "Initial notes"
    model.isPopupEditing = true
    let panel = PromptPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: .borderless, backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    panel.allowsKeyboardInput = true
    defer { panel.close() }
    let host = NSHostingView(rootView: PopupTextEditor(text: Binding(get: { model.notes }, set: { model.notes = $0 }), editing: true, textSize: 17, onDone: { model.isPopupEditing = false }))
    host.sizingOptions = []
    panel.contentView = host
    host.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(30))
    func findEditor(_ view: NSView) -> PopupTextEditor.TextView? {
        if let editor = view as? PopupTextEditor.TextView { return editor }
        for child in view.subviews { if let editor = findEditor(child) { return editor } }
        return nil
    }
    let editor = try #require(findEditor(host))
    #expect(editor.isEditable)
    #expect(editor.string == "Initial notes")
    #expect(panel.firstResponder === editor)
    editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
    editor.insertText(" appended", replacementRange: editor.selectedRange())
    #expect(model.notes == "Initial notes appended")
    let escape = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
    editor.keyDown(with: escape)
    #expect(!model.isPopupEditing)
}

@Test @MainActor func sectionsKeepTheirOwnListsSelectionsContentAndAppearance() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "session.json")
    let model = PromptModel(saveURL: url)
    model.text = "One two three four five."
    let readID = model.activeChapterID
    model.activateWord(at: 3)
    model.textSize = 22
    model.openOnHover = true
    model.isConfigurationExpanded = true
    model.isChaptersExpanded = true
    model.togglePlayback()
    model.activeTab = .cards
    #expect(!model.isPlaying)
    #expect(model.activeChapterID != readID)
    #expect(model.visibleTitles.count == 1)
    #expect(!model.isConfigurationExpanded)
    #expect(!model.isChaptersExpanded)
    model.textSize = 32
    model.width = 420
    model.transparency = 40
    model.openOnHover = false
    let deckID = model.activeChapterID
    model.addCard()
    let firstCard = try #require(model.activeCard?.id)
    model.cardTitle = "First point"
    model.cardDetails = "Details for the first point"
    model.cardNotes = "An observation"
    model.toggleCardCompleted()
    model.addCard()
    let secondCard = try #require(model.activeCard?.id)
    model.cardTitle = "Second point"
    model.activeTab = .notes
    #expect(model.cards.isEmpty)
    #expect(model.notes.isEmpty)
    #expect(model.transparency == 0)
    let noteID = model.activeChapterID
    model.notes = "General notes"
    model.addChapter()
    model.notes = "Other notes"
    #expect(model.visibleTitles.count == 2)
    model.activeTab = .read
    #expect(model.activeChapterID == readID)
    #expect(model.visibleTitles.count == 1)
    #expect(model.wordIndex == 3)
    #expect(model.textSize == 22)
    #expect(model.openOnHover)
    #expect(model.isConfigurationExpanded)
    #expect(model.isChaptersExpanded)
    model.activeTab = .notes
    #expect(model.notes == "Other notes")
    model.selectChapter(noteID)
    #expect(model.notes == "General notes")
    model.activeTab = .cards
    #expect(model.activeChapterID == deckID)
    #expect(model.activeCard?.id == secondCard)
    #expect(model.textSize == 32)
    #expect(model.width == 420)
    #expect(model.transparency == 40)
    #expect(!model.openOnHover)
    model.save()

    let restored = PromptModel(saveURL: url)
    #expect(restored.activeTab == .cards)
    #expect(restored.activeChapterID == deckID)
    #expect(restored.activeCard?.id == secondCard)
    #expect(restored.width == 420)
    restored.selectCard(firstCard)
    #expect(restored.cardTitle == "First point")
    #expect(restored.cardDetails == "Details for the first point")
    #expect(restored.cardNotes == "An observation")
    #expect(restored.activeCard?.completed == true)
    restored.activeTab = .notes
    #expect(restored.activeChapterID == noteID)
    #expect(restored.notes == "General notes")
    restored.activeTab = .read
    #expect(restored.text == "One two three four five.")
    #expect(restored.wordIndex == 3)
    #expect(!restored.isPlaying)
    restored.save()
}

@Test @MainActor func migratingSharedTabsSplitsContentWithoutDuplicatingItOnReload() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "session.json")
    let card = CueCard(title: "A point", details: "Details", notes: "Card notes")
    let original = Chapter(title: "My title", text: "Read this content.", readingPosition: ReadingPosition(wordIndex: 2, wordProgress: 0, finished: false), cards: [card], selectedCardID: card.id, notes: "My notes", selectedTab: .cards)
    var session = SavedSession()
    session.chapters = [original]
    session.activeChapterID = original.id
    try JSONEncoder().encode(session).write(to: url)
    let model = PromptModel(saveURL: url)
    #expect(model.activeTab == .cards)
    #expect(model.cardTitle == "A point")
    #expect(model.cardNotes == "Card notes")
    #expect(model.chapters.count == 3)
    model.activeTab = .notes
    #expect(model.notes == "My notes")
    model.activeTab = .read
    #expect(model.activeChapterID == original.id)
    #expect(model.text == "Read this content.")
    #expect(model.wordIndex == 2)
    model.save()
    let restored = PromptModel(saveURL: url)
    #expect(restored.chapters.count == 3)
    #expect(restored.activeChapterID == original.id)
    restored.activeTab = .cards
    #expect(restored.cards.count == 1)
    #expect(restored.activeCard?.id == card.id)
}

@Test @MainActor func cardNavigationDeletionAndImportRespectWorkspaceContext() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = "Reading content remains intact."
    model.activeTab = .notes
    model.importContent("Independent notes")
    model.navigate(forward: true)
    #expect(model.wordIndex == 0)
    #expect(model.exportContent == "Independent notes")
    model.activeTab = .cards
    model.importContent(" First\n\nSecond\nThird ")
    #expect(model.cards.count == 3)
    #expect(model.cardTitle == "First")
    model.navigate(forward: false)
    #expect(model.activeCardIndex == 0)
    model.navigate(forward: true)
    #expect(model.cardTitle == "Second")
    model.cardNotes = "Second card notes"
    model.navigate(forward: true)
    let last = model.activeCard!.id
    model.navigate(forward: true)
    #expect(model.activeCard?.id == last)
    model.deleteCard(last)
    #expect(model.cardTitle == "Second")
    #expect(model.cardNotes == "Second card notes")
    #expect(model.exportContent.contains("Second card notes"))
    model.deleteCard(model.activeCard!.id)
    model.deleteCard(model.activeCard!.id)
    #expect(model.activeCard == nil)
    model.navigate(forward: true)
    model.toggleCardCompleted()
    model.activeTab = .read
    #expect(model.text == "Reading content remains intact.")
    #expect(model.wordIndex == 0)
    model.activeTab = .notes
    #expect(model.notes == "Independent notes")
}

@Test @MainActor func popupEditingEndsOnTabTitleAndVisibilityChanges() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    var events: [Bool] = []
    model.onPopupEditingChange = { events.append($0) }
    model.activeTab = .notes
    model.isPopupEditing = true
    model.notes = "Saved before leaving"
    model.activeTab = .cards
    #expect(events == [true, false])
    model.addCard()
    model.isPopupEditing = true
    model.addChapter()
    #expect(!model.isPopupEditing)
    model.isPopupEditing = true
    model.collapsePopup()
    #expect(!model.isPopupEditing)
    #expect(!model.isPlaying)
}

@Test @MainActor func renamingDefaultTitlesPreservesCustomNamesContentAndSelection() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "session.json")
    let first = Chapter(title: "Chapter 1", text: "Opening content")
    let custom = Chapter(title: "Chapter planning", text: "Custom content")
    var session = SavedSession()
    session.chapters = [first, custom]
    session.activeChapterID = custom.id
    try JSONEncoder().encode(session).write(to: url)
    let model = PromptModel(saveURL: url)
    #expect(model.chapters[0].title == "Title 1")
    #expect(model.chapters[0].id == first.id)
    #expect(model.chapters[0].text == "Opening content")
    #expect(model.activeChapterTitle == "Chapter planning")
    #expect(model.activeChapterID == custom.id)
    #expect(model.text == "Custom content")
}

@Test @MainActor func popupCursorUsesTheVisibleControlUnderThePointer() {
    _ = NSApplication.shared
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: .borderless, backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    window.contentView = root
    let hand = NSCursor.pointingHand
    let resize = NSCursor.resizeLeftRight
    let arrow = NSCursor.arrow
    let button = CursorRegion.RegionView(frame: NSRect(x: 20, y: 20, width: 60, height: 32))
    button.cursor = hand
    root.addSubview(button)
    let slider = CursorRegion.RegionView(frame: NSRect(x: 20, y: 80, width: 200, height: 24))
    slider.cursor = resize
    root.addSubview(slider)
    #expect(CursorRegion.cursor(at: NSPoint(x: 40, y: 30), in: root) === hand)
    #expect(CursorRegion.cursor(at: NSPoint(x: 40, y: 90), in: root) === resize)
    #expect(CursorRegion.cursor(at: NSPoint(x: 300, y: 200), in: root) == nil)
    button.cursor = arrow
    #expect(CursorRegion.cursor(at: NSPoint(x: 40, y: 30), in: root) === arrow)
    button.isHidden = true
    #expect(CursorRegion.cursor(at: NSPoint(x: 40, y: 30), in: root) == nil)
}

@Test @MainActor func popupDrawersAddSpaceWithoutChangingSavedReadingHeight() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.height = 300
    model.configurationContentHeight = 94
    model.isConfigurationExpanded = true
    #expect(model.expandedPopupHeight == 394)
    model.isChaptersExpanded = true
    #expect(model.expandedPopupHeight == 394 + model.chapterListHeight)
    // Wrapping controls at narrower widths measures a taller drawer.
    model.configurationContentHeight = 128
    #expect(model.expandedPopupHeight == 428 + model.chapterListHeight)
    model.isConfigurationExpanded = false
    model.isChaptersExpanded = false
    #expect(model.expandedPopupHeight == 300)
    #expect(model.height == 300)
}

@Test @MainActor func chaptersMigrateLegacyTextAndPersistIndependentContent() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "session.json")
    try Data(#"{"text":"Legacy words stay safe."}"#.utf8).write(to: url)
    let model = PromptModel(saveURL: url)
    #expect(model.chapters.count == 1)
    #expect(model.text == "Legacy words stay safe.")
    let first = model.activeChapterID
    model.activeChapterTitle = "Opening"
    model.togglePlayback()
    model.addChapter()
    #expect(!model.isPlaying)
    #expect(model.text.isEmpty)
    let second = model.activeChapterID
    model.activeChapterTitle = "Details"
    model.text = "Second chapter content."
    model.selectChapter(first)
    #expect(model.text == "Legacy words stay safe.")
    #expect(model.activeChapterTitle == "Opening")
    #expect(model.wordIndex == 0)
    model.save()
    let restored = PromptModel(saveURL: url)
    #expect(restored.activeChapterID == first)
    #expect(restored.chapters.count == 2)
    restored.selectChapter(second)
    #expect(restored.text == "Second chapter content.")
    #expect(restored.activeChapterTitle == "Details")
    restored.deleteChapter(second)
    #expect(restored.activeChapterID == first)
    #expect(restored.text == "Legacy words stay safe.")
    restored.deleteChapter(first)
    #expect(restored.chapters.count == 1)
    restored.save()
}

@Test @MainActor func switchingTitlesWithIdenticalContentRestoresIndependentPositions() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = "Same words in both chapters."
    let first = model.activeChapterID
    model.activateWord(at: 1)
    model.addChapter()
    let second = model.activeChapterID
    model.text = "Same words in both chapters."
    model.activateWord(at: 3)
    model.togglePlayback()
    model.selectChapter(first)
    #expect(model.wordIndex == 1)
    #expect(!model.isPlaying)
    #expect(!model.finished)
    model.selectChapter(second)
    #expect(model.wordIndex == 3)
    #expect(!model.isPlaying)
}

@Test @MainActor func titlePositionsSurviveRelaunchAndEditingResetsOnlyEditedTitle() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "session.json")
    let model = PromptModel(saveURL: url)
    model.text = "One two three four five six seven."
    let first = model.activeChapterID
    model.activateWord(at: 4)
    model.addChapter()
    model.text = "Another title with different content."
    let second = model.activeChapterID
    model.activateWord(at: 2)
    model.save()

    let restored = PromptModel(saveURL: url)
    #expect(restored.activeChapterID == second)
    #expect(restored.wordIndex == 2)
    #expect(!restored.isPlaying)
    restored.selectChapter(first)
    #expect(restored.wordIndex == 4)
    restored.activeChapterTitle = "Renamed"
    #expect(restored.wordIndex == 4)
    restored.text = "Edited content."
    #expect(restored.wordIndex == 0)
    restored.selectChapter(second)
    #expect(restored.wordIndex == 2)
    restored.reset()
    restored.selectChapter(first)
    restored.selectChapter(second)
    #expect(restored.wordIndex == 0)
    restored.save()
}

@Test @MainActor func completedTitleStaysCompleteAfterSwitchingAndReloading() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "session.json")
    let model = PromptModel(saveURL: url)
    model.text = "One two three."
    model.mode = .voice
    let first = model.activeChapterID
    model.togglePlayback()
    model.voiceDidStart()
    model.followVoice("One two three")
    #expect(model.finished)
    model.addChapter()
    model.selectChapter(first)
    #expect(model.finished)
    #expect(model.wordIndex == 2)
    #expect(!model.isPlaying)
    model.save()
    let restored = PromptModel(saveURL: url)
    #expect(restored.finished)
    #expect(restored.wordIndex == 2)
    #expect(!restored.isPlaying)
    // Explicit Read again still starts from the beginning.
    restored.togglePlayback()
    #expect(restored.wordIndex == 0)
    #expect(!restored.finished)
    restored.pause()
    restored.save()
}

@Test func wordClicksResolveUnicodeTextButIgnoreWhitespace() {
    let text = "Hello 👋🏽\nनमस्ते दुनिया"
    let script = Script(text)
    for (index, word) in script.words.enumerated() {
        #expect(script.wordIndex(containingUTF16: word.range.location) == index)
        #expect(script.wordIndex(containingUTF16: NSMaxRange(word.range) - 1) == index)
    }
    #expect(script.wordIndex(containingUTF16: 5) == nil)
    #expect(script.wordIndex(containingUTF16: (text as NSString).length) == nil)
}

@Test @MainActor func clickingWordPreservesPlaybackAndRejectsInvalidPositions() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = "One two three four five."
    model.activateWord(at: 3)
    #expect(model.wordIndex == 3)
    #expect(!model.isPlaying)
    model.togglePlayback()
    model.activateWord(at: 1)
    #expect(model.wordIndex == 1)
    #expect(model.isPlaying)
    model.activateWord(at: -1)
    model.activateWord(at: 100)
    #expect(model.wordIndex == 1)
    model.pause()
}

@Test @MainActor func explicitShowPinsBeforeRevealingAndToggleDismissesOpenPopup() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    var showedPinned = false
    var dismissed = false
    model.onReveal = { showedPinned = model.isPinned && model.isVisible; model.isExpanded = true }
    model.onDismiss = { dismissed = true }
    model.isExpanded = false
    model.togglePopup()
    #expect(showedPinned)
    #expect(model.isPinned)
    model.togglePopup()
    #expect(dismissed)
}

@Test @MainActor func readingStartRequestsEditorDismissalButPauseDoesNot() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    var dismissals = 0
    model.onReadingStarted = { dismissals += 1 }
    model.togglePlayback()
    #expect(model.isPlaying)
    #expect(dismissals == 1)
    model.togglePlayback()
    #expect(!model.isPlaying)
    #expect(dismissals == 1)
}

@Test @MainActor func dismissingPopupKeepsHoverArmedAndEnablingHoverRearmsHiddenPanel() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.openOnHover = true
    model.isPinned = true
    model.isVisible = false
    model.dismissPopup()
    #expect(model.openOnHover)
    #expect(model.isVisible)
    #expect(!model.isPinned)
    #expect(!model.isPlaying)
    model.openOnHover = false
    model.isVisible = false
    model.openOnHover = true
    #expect(model.isVisible)
}

@Test @MainActor func draggingUsesOriginalHeightAndClampsAtBothEnds() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.height = 300
    model.resizePopup(by: 50)
    #expect(model.height == 350)
    model.resizePopup(by: 100)
    #expect(model.height == 400)
    #expect(model.isResizing)
    model.resizePopup(by: 900)
    #expect(model.height == 700)
    model.endResizing()
    #expect(!model.isResizing)
    model.resizePopup(by: -900)
    #expect(model.height == 220)
    model.endResizing()
}

@Test func pushingPointerAgainstTopBorderStillActivatesNotch() {
    for origin in [CGPoint.zero, CGPoint(x: 1400, y: 200)] {
        let screen = CGRect(origin: origin, size: CGSize(width: 1500, height: 1000))
        let hotspot = PanelGeometry.hotspot(frame: screen, safeTop: 32, notchWidth: 180, menuBarInset: 32)
        #expect(PanelGeometry.isOverNotch(CGPoint(x: screen.midX, y: screen.maxY), hotspot: hotspot))
        #expect(PanelGeometry.isOverNotch(CGPoint(x: hotspot.minX, y: screen.maxY), hotspot: hotspot))
        #expect(PanelGeometry.isOverNotch(CGPoint(x: hotspot.maxX, y: screen.maxY), hotspot: hotspot))
        #expect(!PanelGeometry.isOverNotch(CGPoint(x: hotspot.minX - 1, y: screen.maxY), hotspot: hotspot))
        #expect(!PanelGeometry.isOverNotch(CGPoint(x: hotspot.maxX + 1, y: screen.maxY), hotspot: hotspot))
        #expect(!PanelGeometry.isOverNotch(CGPoint(x: screen.midX, y: screen.maxY + 1), hotspot: hotspot))
    }
}

@Test func hoverTargetStaysInsideNotchWhileControlsRemainBelowIt() {
    let frame = CGRect(x: 1400, y: 200, width: 1500, height: 1000)
    let hotspot = PanelGeometry.hotspot(frame: frame, safeTop: 32, notchWidth: 180, menuBarInset: 32)
    #expect(hotspot == CGRect(x: 2060, y: 1168, width: 180, height: 32))
    #expect(!hotspot.contains(CGPoint(x: 2150, y: 1167)))
    #expect(hotspot.contains(CGPoint(x: 2150, y: 1180)))
    #expect(!hotspot.contains(CGPoint(x: 1950, y: 1180)))
    #expect(!hotspot.contains(CGPoint(x: 2350, y: 1180)))
    #expect(!hotspot.contains(CGPoint(x: 2500, y: 1180)))
    let popup = PanelGeometry.panelFrame(screen: frame, width: 540, height: 268, menuBarInset: 32)
    #expect(popup.maxY == hotspot.minY)
    #expect(popup.midX == hotspot.midX)
    #expect(!popup.contains(CGPoint(x: 1950, y: 1180)))
    #expect(popup.contains(CGPoint(x: 1950, y: 1100)))

    let strip = PanelGeometry.panelFrame(screen: frame, width: 210, height: 26, menuBarInset: 24)
    let stripHotspot = PanelGeometry.hotspot(frame: frame, safeTop: 0, notchWidth: 0, menuBarInset: 24)
    #expect(strip.maxY == frame.maxY - 24)
    #expect(stripHotspot.contains(CGPoint(x: strip.midX, y: strip.midY)))
}

@Test func olderSavedScriptsRetainTheirSettingsWhenTransparencyIsAdded() throws {
    let old = Data(#"{"text":"Keep this script","speed":185,"textSize":28,"width":680,"height":320,"mode":"Manual","openOnHover":false,"voiceLocale":"en-IN"}"#.utf8)
    let restored = try JSONDecoder().decode(SavedSession.self, from: old)
    #expect(restored.text == "Keep this script")
    #expect(restored.speed == 185)
    #expect(restored.mode == .manual)
    #expect(restored.transparency == 0)
}

@Test func multilingualRangesPointToOriginalWords() {
    let text = "Hello 👋🏽 world!\nनमस्ते दुनिया।\nAaj hum build karenge."
    let script = Script(text)
    #expect(script.words.count == 9)
    for word in script.words {
        #expect((text as NSString).substring(with: word.range) == word.text)
    }
    #expect(script.paragraphStarts == [0, 3, 5])
}

@Test func paragraphNavigationSkipsSentencesAndHandlesEndOfScript() {
    let script = Script("First sentence. Still same paragraph.\n\nSecond paragraph. Another sentence.\nThird paragraph.")
    #expect(script.paragraphStarts == [0, 5, 9])
    #expect(script.nextParagraph(from: 0) == 5)
    #expect(script.nextParagraph(from: 5) == 9)
    #expect(script.nextParagraph(from: 9) == 9)
    #expect(script.previousParagraph(from: 9) == 5)
    #expect(script.previousParagraph(from: 7) == 5)
    #expect(Script(" \n ").nextParagraph(from: 0) == 0)
    #expect(Script("").duration(at: 150) == 0)
}

@Test func removedBlackColorMigratesWithoutLosingSavedScript() throws {
    let data = Data(#"{"text":"Keep my script intact.","ink":"Charcoal","speed":160}"#.utf8)
    let restored = try JSONDecoder().decode(SavedSession.self, from: data)
    #expect(restored.text == "Keep my script intact.")
    #expect(restored.speed == 160)
    #expect(restored.ink == .cyan)
    #expect(PromptInk.allCases.count == 4)
}

@Test @MainActor func saveRestoresScriptAndSettings() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "session.json")
    let model = PromptModel(saveURL: url)
    model.text = "Aaj hum ek naya tool banayenge. 👋"
    model.speed = 185
    model.playbackRate = 1.25
    model.transparency = 100
    model.ink = .yellow
    model.width = 680
    model.mode = .manual
    model.openOnHover = false
    model.save()
    let restored = PromptModel(saveURL: url)
    #expect(restored.text == model.text)
    #expect(restored.speed == 185)
    #expect(restored.playbackRate == 1.25)
    #expect(restored.effectiveSpeed == 231.25)
    #expect(restored.transparency == 100)
    #expect(restored.ink == .yellow)
    #expect(restored.width == 680)
    #expect(restored.mode == .manual)
    #expect(!restored.openOnHover)
    #expect(restored.wordIndex == 0)
    #expect(!restored.isPlaying)
}

@Test @MainActor func playbackRatesChangeReadingDurationWithoutChangingBasePace() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = Array(repeating: "word", count: 150).joined(separator: " ")
    model.speed = 150
    #expect(model.durationLabel == "1:00")
    model.playbackRate = 1.25
    #expect(model.durationLabel == "0:48")
    #expect(model.speed == 150)
    model.playbackRate = 2
    #expect(model.durationLabel == "0:30")
}

@Test func voiceAlignmentCanCatchUpWithoutJumpingOnCommonWords() {
    let script = Script("Welcome to the channel. Today we build a useful tool. Let’s skip this line. Now let’s test voice tracking.")
    #expect(script.followPosition(transcript: "welcome to the channel", from: 0) == 3)
    #expect(script.followPosition(transcript: "now let’s test voice", from: 3) == 17)
    #expect(script.followPosition(transcript: "the", from: 0) == nil)
    #expect(script.followPosition(transcript: "unrelated spoken words", from: 3) == nil)
    #expect(Script("").followPosition(transcript: "hello", from: 0) == nil)
    let hindi = Script("नमस्ते दोस्तों। आज हम एक टूल बनाएंगे।")
    #expect(hindi.followPosition(transcript: "आज हम", from: 0) == 3)
}

@Test @MainActor func manualModeNeverStartsTimer() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.mode = .manual
    model.togglePlayback()
    #expect(!model.isPlaying)
    #expect(!model.isStartingVoice)
    model.mode = .voice
    model.togglePlayback()
    #expect(model.isStartingVoice)
    model.pause()
    #expect(!model.isStartingVoice)
    model.voiceDidStart()
    #expect(!model.isPlaying)
}

@Test @MainActor func editingAndRestartResetPlaybackPosition() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = "First.\nSecond.\nThird."
    model.jump(forward: true)
    #expect(model.wordIndex == 1)
    model.text = "Replacement script."
    #expect(model.wordIndex == 0)
    #expect(!model.isPlaying)
    model.text = ""
    model.togglePlayback()
    #expect(!model.isPlaying)
}

@Test @MainActor func hidingPopupPausesAndPreservesActiveWordAcrossReopening() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.text = "One two three four five six."
    model.onReveal = { model.isExpanded = true }
    model.activateWord(at: 3)
    model.togglePlayback()
    #expect(model.isPlaying)
    model.collapsePopup()
    #expect(!model.isPlaying)
    #expect(!model.isExpanded)
    #expect(model.wordIndex == 3)
    model.showPinnedPopup()
    #expect(model.wordIndex == 3)
    #expect(!model.isPlaying)
    let unchanged = model.text
    model.text = unchanged
    #expect(model.wordIndex == 3)
    model.dismissPopup()
    #expect(model.wordIndex == 3)
    model.showPinnedPopup()
    model.togglePlayback()
    #expect(model.isPlaying)
    #expect(model.wordIndex == 3)
    model.pause()
}

@Test @MainActor func fontSizeButtonsRespectBoundsWithoutChangingPosition() {
    let model = PromptModel(saveURL: URL(filePath: "/dev/null/not-a-session"))
    model.activateWord(at: 2)
    model.textSize = 18
    model.adjustTextSize(by: -1)
    #expect(model.textSize == 18)
    model.adjustTextSize(by: 1)
    #expect(model.textSize == 19)
    model.textSize = 36
    model.adjustTextSize(by: 1)
    #expect(model.textSize == 36)
    #expect(model.wordIndex == 2)
}

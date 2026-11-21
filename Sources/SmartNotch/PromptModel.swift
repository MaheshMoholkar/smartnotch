import AppKit
import Observation

@Observable
final class PromptModel {
    let updates = AppUpdates()
    var text: String {
        didSet {
            guard text != oldValue else { return }
            script = Script(text)
            guard !isSwitchingChapter else { return }
            if let index = chapters.firstIndex(where: { $0.id == activeChapterID }) {
                chapters[index].text = text
            }
            reset()
        }
    }
    private(set) var chapters: [Chapter]
    private(set) var activeChapterID: UUID
    private var activeTitleIndex: Int { chapters.firstIndex(where: { $0.id == activeChapterID }) ?? 0 }
    private var workspaceTab: WorkspaceTab = .read
    private var titleSelections: [String: UUID] = [:]
    private var workspaceAppearances: [String: WorkspaceAppearance] = [:]
    private var configurationOpen: [WorkspaceTab: Bool] = [:]
    private var titleListOpen: [WorkspaceTab: Bool] = [:]
    var visibleTitles: [Chapter] { chapters.filter { ($0.workspace ?? .read) == workspaceTab } }
    var activeTab: WorkspaceTab {
        get { workspaceTab }
        set {
            guard newValue != workspaceTab else { return }
            let candidates = chapters.filter { ($0.workspace ?? .read) == newValue }
            if let target = candidates.first(where: { $0.id == titleSelections[newValue.rawValue] }) ?? candidates.first {
                selectChapter(target.id)
            } else {
                let title = Chapter(title: "Title 1", text: "", workspace: newValue)
                chapters.append(title)
                selectChapter(title.id)
            }
        }
    }
    var notes: String {
        get { chapters[activeTitleIndex].notes ?? "" }
        set { chapters[activeTitleIndex].notes = newValue; saveSoon() }
    }
    var cards: [CueCard] { chapters[activeTitleIndex].cards ?? [] }
    var activeCardIndex: Int { cards.firstIndex(where: { $0.id == chapters[activeTitleIndex].selectedCardID }) ?? 0 }
    var activeCard: CueCard? { cards.indices.contains(activeCardIndex) ? cards[activeCardIndex] : nil }
    var cardTitle: String {
        get { activeCard?.title ?? "" }
        set { updateCard(\.title, value: newValue) }
    }
    var cardDetails: String {
        get { activeCard?.details ?? "" }
        set { updateCard(\.details, value: newValue) }
    }
    var cardNotes: String {
        get { activeCard?.notes ?? "" }
        set { updateCard(\.notes, value: newValue) }
    }
    var cardToDelete: UUID?
    var isCardListExpanded = false { didSet { onLayoutChange?() } }
    var cardListHeight: Double { min(180, Double(cards.count) * 38 + 36) }
    var isPopupEditing = false { didSet { if oldValue != isPopupEditing { onPopupEditingChange?(isPopupEditing) } } }
    @ObservationIgnored var onPopupEditingChange: ((Bool) -> Void)?

    private func updateCard(_ field: WritableKeyPath<CueCard, String>, value: String) {
        guard !cards.isEmpty else { return }
        let titleIndex = activeTitleIndex
        let cardIndex = activeCardIndex
        chapters[titleIndex].cards?[cardIndex][keyPath: field] = value
        saveSoon()
    }

    func selectCard(_ id: UUID) {
        guard cards.contains(where: { $0.id == id }) else { return }
        isPopupEditing = false
        chapters[activeTitleIndex].selectedCardID = id
        saveSoon()
    }

    func addCard() {
        var items = cards
        let card = CueCard()
        items.append(card)
        chapters[activeTitleIndex].cards = items
        selectCard(card.id)
        onLayoutChange?()
    }

    func deleteCard(_ id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let deletingActive = activeCard?.id == id
        isPopupEditing = false
        var items = cards
        items.remove(at: index)
        chapters[activeTitleIndex].cards = items
        if deletingActive { chapters[activeTitleIndex].selectedCardID = items.isEmpty ? nil : items[min(index, items.count - 1)].id }
        saveSoon()
        onLayoutChange?()
    }

    func moveCard(forward: Bool) {
        let next = activeCardIndex + (forward ? 1 : -1)
        guard cards.indices.contains(next) else { return }
        selectCard(cards[next].id)
    }

    func toggleCardCompleted() {
        guard !cards.isEmpty else { return }
        let titleIndex = activeTitleIndex
        let cardIndex = activeCardIndex
        chapters[titleIndex].cards?[cardIndex].completed.toggle()
        saveSoon()
    }

    func navigate(forward: Bool) {
        if activeTab == .cards { moveCard(forward: forward) }
        else if activeTab == .read { jump(forward: forward) }
    }
    var activeChapterTitle: String {
        get { chapters.first(where: { $0.id == activeChapterID })?.title ?? "Title" }
        set {
            guard let index = chapters.firstIndex(where: { $0.id == activeChapterID }) else { return }
            chapters[index].title = newValue
            saveSoon()
        }
    }
    var isSettingsPresented = false
    var chapterToDelete: Chapter?
    var hoveredChapterID: UUID?
    var isChaptersExpanded: Bool {
        get { titleListOpen[workspaceTab] ?? false }
        set { titleListOpen[workspaceTab] = newValue; onLayoutChange?() }
    }
    var chapterListHeight: Double { min(180, Double(visibleTitles.count) * 38 + 36) }
    var speed: Double { didSet { saveSoon() } }
    var playbackRate: Double { didSet { saveSoon() } }
    var textSize: Double { didSet { saveSoon() } }
    var ink: PromptInk { didSet { saveSoon() } }
    var transparency: Double { didSet { saveSoon() } }
    var width: Double { didSet { saveSoon(); onLayoutChange?() } }
    var height: Double { didSet { saveSoon(); onLayoutChange?() } }
    var mode: ReadingMode { didSet { pause(); saveSoon() } }
    var openOnHover: Bool {
        didSet {
            if openOnHover { isVisible = true }
            saveSoon()
            onLayoutChange?()
        }
    }
    var voiceLocale: String { didSet { pause(); saveSoon() } }
    private(set) var script: Script
    private(set) var wordIndex = 0
    private(set) var isPlaying = false
    private(set) var isStartingVoice = false
    private(set) var finished = false
    var isVisible = true
    var isExpanded = false
    var isPinned = false
    var isResizing = false
    var isResizeHovered = false
    var configurationContentHeight = 90.0 { didSet { onLayoutChange?() } }
    var expandedPopupHeight: Double {
        height + (isConfigurationExpanded ? configurationContentHeight : 0)
            + (isChaptersExpanded ? chapterListHeight : 0)
            + (activeTab == .cards && isCardListExpanded ? cardListHeight : 0)
    }
    var isConfigurationExpanded: Bool {
        get { configurationOpen[workspaceTab] ?? false }
        set { configurationOpen[workspaceTab] = newValue; onLayoutChange?() }
    }
    var cameraCutoutWidth = 0.0
    var errorMessage: String?
    var saveStatus = "Saved on this Mac"
    var shortcutsAvailable = true
    @ObservationIgnored var onLayoutChange: (() -> Void)?
    @ObservationIgnored var onReveal: (() -> Void)?
    @ObservationIgnored var onEditor: (() -> Void)?
    @ObservationIgnored var onDismiss: (() -> Void)?
    @ObservationIgnored var onReadingStarted: (() -> Void)?
    @ObservationIgnored var onVoiceStart: (() -> Void)?
    @ObservationIgnored var onVoiceStop: (() -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var lastTick = Date()
    @ObservationIgnored private var wordProgress = 0.0
    @ObservationIgnored private var resizeStartHeight: Double?
    @ObservationIgnored private var isSwitchingChapter = false
    @ObservationIgnored let saveURL: URL

    init(saveURL: URL? = nil) {
        self.saveURL = saveURL ?? URL.applicationSupportDirectory
            .appending(path: "MaheshLabs/SmartNotch/session.json")
        let session: SavedSession
        if let data = try? Data(contentsOf: self.saveURL), let saved = try? JSONDecoder().decode(SavedSession.self, from: data) {
            session = saved
        } else {
            session = SavedSession()
        }
        let savedChapters = session.chapters.flatMap { $0.isEmpty ? nil : $0 }
            ?? [Chapter(title: "Title 1", text: session.text)]
        var migrated: [Chapter] = []
        var selections = session.titleSelections ?? [:]
        let oldActive = savedChapters.first { $0.id == session.activeChapterID } ?? savedChapters[0]
        let selectedWorkspace = session.workspaceTab ?? oldActive.workspace ?? oldActive.selectedTab ?? .read
        for saved in savedChapters {
            var title = saved
            if title.title.range(of: #"^Chapter [0-9]+$"#, options: .regularExpression) != nil {
                title.title = title.title.replacingOccurrences(of: "Chapter ", with: "Title ")
            }
            if title.workspace == nil {
                title.workspace = .read
                title.selectedTab = nil
                title.cards = nil
                title.selectedCardID = nil
                title.notes = nil
                migrated.append(title)
                if saved.id == oldActive.id { selections[WorkspaceTab.read.rawValue] = title.id }
                if let cards = saved.cards, !cards.isEmpty {
                    let deck = Chapter(title: title.title, text: "", cards: cards, selectedCardID: saved.selectedCardID, workspace: .cards)
                    migrated.append(deck)
                    if saved.id == oldActive.id { selections[WorkspaceTab.cards.rawValue] = deck.id }
                }
                if let notes = saved.notes, !notes.isEmpty {
                    let note = Chapter(title: title.title, text: "", notes: notes, workspace: .notes)
                    migrated.append(note)
                    if saved.id == oldActive.id { selections[WorkspaceTab.notes.rawValue] = note.id }
                }
            } else {
                migrated.append(title)
            }
        }
        if !migrated.contains(where: { $0.workspace == selectedWorkspace }) {
            migrated.append(Chapter(title: "Title 1", text: "", workspace: selectedWorkspace))
        }
        let candidates = migrated.filter { $0.workspace == selectedWorkspace }
        let selectedID = selections[selectedWorkspace.rawValue] ?? session.activeChapterID
        let activeChapter = candidates.first(where: { $0.id == selectedID }) ?? candidates[0]
        chapters = migrated
        workspaceTab = selectedWorkspace
        selections[selectedWorkspace.rawValue] = activeChapter.id
        titleSelections = selections
        let baseline = WorkspaceAppearance(textSize: session.textSize, ink: session.ink, transparency: session.transparency, width: session.width, height: session.height, openOnHover: session.openOnHover)
        var appearances = session.workspaceAppearances ?? [:]
        for tab in WorkspaceTab.allCases where appearances[tab.rawValue] == nil {
            appearances[tab.rawValue] = baseline
        }
        workspaceAppearances = appearances
        let appearance = appearances[selectedWorkspace.rawValue] ?? baseline
        activeChapterID = activeChapter.id
        text = activeChapter.text
        script = Script(activeChapter.text)
        speed = min(240, max(60, session.speed))
        playbackRate = min(2, max(0.5, session.playbackRate))
        textSize = min(36, max(18, appearance.textSize))
        ink = appearance.ink
        transparency = min(100, max(0, appearance.transparency))
        width = min(760, max(360, appearance.width == 540 ? 580 : appearance.width))
        height = min(700, max(220, appearance.height))
        mode = session.mode
        openOnHover = appearance.openOnHover ?? session.openOnHover
        voiceLocale = session.voiceLocale
        restoreReadingPosition(activeChapter.readingPosition)
    }

    func selectChapter(_ id: UUID) {
        guard id != activeChapterID, let chapter = chapters.first(where: { $0.id == id }) else { return }
        pause()
        rememberReadingPosition()
        rememberWorkspaceAppearance()
        isPopupEditing = false
        titleSelections[workspaceTab.rawValue] = activeChapterID
        let nextWorkspace = chapter.workspace ?? .read
        let switchingWorkspace = nextWorkspace != workspaceTab
        workspaceTab = nextWorkspace
        activeChapterID = id
        titleSelections[nextWorkspace.rawValue] = id
        isSwitchingChapter = true
        text = chapter.text
        isSwitchingChapter = false
        restoreReadingPosition(chapter.readingPosition)
        if switchingWorkspace, let appearance = workspaceAppearances[nextWorkspace.rawValue] {
            textSize = min(36, max(18, appearance.textSize))
            ink = appearance.ink
            transparency = min(100, max(0, appearance.transparency))
            width = min(760, max(360, appearance.width))
            height = min(700, max(220, appearance.height))
            if let hover = appearance.openOnHover { openOnHover = hover }
        }
        saveSoon()
        onLayoutChange?()
    }

    private func rememberWorkspaceAppearance() {
        workspaceAppearances[workspaceTab.rawValue] = WorkspaceAppearance(textSize: textSize, ink: ink, transparency: transparency, width: width, height: height, openOnHover: openOnHover)
    }

    private func rememberReadingPosition() {
        guard let index = chapters.firstIndex(where: { $0.id == activeChapterID }) else { return }
        chapters[index].readingPosition = ReadingPosition(wordIndex: wordIndex, wordProgress: wordProgress, finished: finished)
    }

    private func restoreReadingPosition(_ position: ReadingPosition?) {
        wordIndex = min(max(0, position?.wordIndex ?? 0), max(0, script.words.count - 1))
        let fraction = position?.wordProgress ?? 0
        wordProgress = fraction.isFinite ? min(0.9999, max(0, fraction)) : 0
        finished = position?.finished == true && !script.words.isEmpty && wordIndex == script.words.count - 1
        if finished || script.words.isEmpty { wordProgress = 0 }
        lastTick = Date()
    }

    func addChapter() {
        let chapter = Chapter(title: "Title \(visibleTitles.count + 1)", text: "", workspace: workspaceTab)
        chapters.append(chapter)
        selectChapter(chapter.id)
        onLayoutChange?()
    }

    func deleteChapter(_ id: UUID) {
        guard let chapter = chapters.first(where: { $0.id == id }) else { return }
        let siblings = chapters.filter { ($0.workspace ?? .read) == (chapter.workspace ?? .read) }
        guard siblings.count > 1, let index = siblings.firstIndex(where: { $0.id == id }) else { return }
        if id == activeChapterID { selectChapter(siblings[index == siblings.count - 1 ? index - 1 : index + 1].id) }
        chapters.removeAll { $0.id == id }
        saveSoon()
        onLayoutChange?()
    }

    var durationLabel: String {
        let seconds = script.duration(at: effectiveSpeed)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
    var effectiveSpeed: Double { speed * playbackRate }
    var playbackRateLabel: String { "\(playbackRate.formatted(.number.precision(.fractionLength(0...2))))×" }
    var progress: Double { script.words.isEmpty ? 0 : Double(finished ? script.words.count : wordIndex) / Double(script.words.count) }
    var readingStatus: String { finished ? "Complete" : isStartingVoice ? "Starting mic…" : isPlaying ? (mode == .voice ? "Listening" : "Reading") : "Ready" }

    func togglePlayback() {
        guard activeTab == .read else { showPinnedPopup(); onReadingStarted?(); return }
        if isPlaying || isStartingVoice { pause(); return }
        guard !script.words.isEmpty else { return }
        if finished { reset() }
        if mode == .manual { showPinnedPopup(); onReadingStarted?(); return }
        onReveal?()
        if mode == .voice {
            isStartingVoice = true
            onVoiceStart?()
            return
        }
        isPlaying = true
        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        onReadingStarted?()
    }

    private func tick() {
        let now = Date()
        wordProgress += min(0.2, now.timeIntervalSince(lastTick)) * effectiveSpeed / 60
        lastTick = now
        while wordProgress >= 1 {
            wordProgress -= 1
            if wordIndex + 1 < script.words.count {
                wordIndex += 1
            } else {
                pause()
                finished = true
                break
            }
        }
    }

    func pause() {
        let wasActive = isPlaying || isStartingVoice
        timer?.invalidate(); timer = nil
        isPlaying = false
        isStartingVoice = false
        onVoiceStop?()
        rememberReadingPosition()
        if wasActive { saveSoon() }
    }
    func voiceDidStart() {
        guard mode == .voice, isStartingVoice else { return }
        isStartingVoice = false
        isPlaying = true
        onReadingStarted?()
    }
    func followVoice(_ transcript: String) {
        guard mode == .voice, isPlaying,
              let index = script.followPosition(transcript: transcript, from: wordIndex) else { return }
        wordIndex = index
        if wordIndex == script.words.count - 1 { pause(); finished = true }
    }
    func reset() {
        pause()
        wordIndex = 0; wordProgress = 0; finished = false
        rememberReadingPosition()
        saveSoon()
    }
    func jump(forward: Bool) {
        guard !script.words.isEmpty else { return }
        wordIndex = forward ? script.nextParagraph(from: wordIndex) : script.previousParagraph(from: wordIndex)
        wordProgress = 0
        finished = false
        saveSoon()
    }

    func activateWord(at index: Int) {
        guard script.words.indices.contains(index) else { return }
        let restartVoice = mode == .voice && isPlaying
        if restartVoice { pause() }
        wordIndex = index
        wordProgress = 0
        lastTick = Date()
        finished = false
        if restartVoice { togglePlayback() }
        saveSoon()
    }

    func resizePopup(by translation: Double) {
        if resizeStartHeight == nil { resizeStartHeight = height }
        isResizing = true
        height = min(700, max(220, (resizeStartHeight ?? height) + translation))
    }

    func endResizing() { resizeStartHeight = nil; isResizing = false }

    func adjustTextSize(by amount: Double) {
        textSize = min(36, max(18, textSize + amount))
    }

    func collapsePopup() {
        isPopupEditing = false
        if isPlaying || isStartingVoice { pause() }
        isExpanded = false
    }

    func dismissPopup() {
        collapsePopup()
        isPinned = false
        isVisible = true
        isResizeHovered = false
        endResizing()
    }

    func showPinnedPopup() {
        isVisible = true
        isPinned = true
        onReveal?()
    }

    func togglePopup() {
        if isVisible && isExpanded { onDismiss?() }
        else { showPinnedPopup() }
    }

    func saveSoon() {
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            self?.save()
        }
    }

    @discardableResult func save() -> Bool {
        saveTask?.cancel()
        saveTask = nil
        rememberReadingPosition()
        rememberWorkspaceAppearance()
        titleSelections[workspaceTab.rawValue] = activeChapterID
        let session = SavedSession(text: text, speed: speed, textSize: textSize, width: width, height: height, mode: mode, openOnHover: openOnHover, voiceLocale: voiceLocale, transparency: transparency, playbackRate: playbackRate, ink: ink, chapters: chapters, activeChapterID: activeChapterID, workspaceTab: workspaceTab, titleSelections: titleSelections, workspaceAppearances: workspaceAppearances)
        do {
            try FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(session).write(to: saveURL, options: .atomic)
            saveStatus = "Saved on this Mac"
            return true
        } catch {
            saveStatus = "Couldn’t save"
            errorMessage = "Your script could not be saved: \(error.localizedDescription)"
            return false
        }
    }

    func importScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.message = activeTab == .cards ? "Choose text with one card per non-empty line. Cards are added to this title." : "Choose text or Markdown. This replaces the current \(activeTab.rawValue.lowercased()) content."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { importContent(try String(contentsOf: url, encoding: .utf8)) }
        catch { errorMessage = "Couldn’t open this file as UTF-8 text: \(error.localizedDescription)" }
    }

    func importContent(_ content: String) {
        switch activeTab {
        case .read: text = content
        case .notes: notes = content
        case .cards:
            let additions = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                .map { CueCard(title: $0) }
            guard let first = additions.first else { return }
            chapters[activeTitleIndex].cards = cards + additions
            selectCard(first.id)
            onLayoutChange?()
        }
    }

    var exportContent: String {
        switch activeTab {
        case .read: text
        case .notes: notes
        case .cards:
            cards.enumerated().map { index, card in
                let title = card.title.isEmpty ? "Card \(index + 1)" : card.title
                return ["\(card.completed ? "[x]" : "[ ]") \(title)", card.details, card.notes.isEmpty ? "" : "Notes:\n\(card.notes)"]
                    .filter { !$0.isEmpty }.joined(separator: "\n\n")
            }.joined(separator: "\n\n---\n\n")
        }
    }

    func exportScript() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(activeChapterTitle.isEmpty ? "Title" : activeChapterTitle) - \(activeTab.rawValue).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try exportContent.write(to: url, atomically: true, encoding: .utf8) }
        catch { errorMessage = "Couldn’t export this content: \(error.localizedDescription)" }
    }
}

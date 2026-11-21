import Foundation

nonisolated struct Script {
    struct Word {
        let text: String
        let range: NSRange
    }
    let words: [Word]
    let paragraphStarts: [Int]

    init(_ text: String) {
        let expression = try! NSRegularExpression(pattern: "\\S+")
        let source = text as NSString
        words = expression.matches(in: text, range: NSRange(location: 0, length: source.length)).map {
            Word(text: source.substring(with: $0.range), range: $0.range)
        }
        var starts = [Int]()
        for index in words.indices {
            if index == 0 {
                starts.append(index)
            } else {
                let previous = words[index - 1]
                let gap = source.substring(with: NSRange(
                    location: NSMaxRange(previous.range),
                    length: words[index].range.location - NSMaxRange(previous.range)
                ))
                if gap.contains("\n") || gap.contains("\r") || gap.contains("\u{2029}") {
                    starts.append(index)
                }
            }
        }
        paragraphStarts = starts
    }

    func nextParagraph(from index: Int) -> Int {
        paragraphStarts.first(where: { $0 > index }) ?? min(max(0, index), max(0, words.count - 1))
    }

    func previousParagraph(from index: Int) -> Int {
        paragraphStarts.last(where: { $0 < index }) ?? 0
    }

    func wordIndex(containingUTF16 character: Int) -> Int? {
        words.firstIndex { NSLocationInRange(character, $0.range) }
    }

    func duration(at wordsPerMinute: Double) -> Int {
        Int(ceil(Double(words.count) / max(1, wordsPerMinute) * 60))
    }

    static func normalized(_ word: String) -> String {
        String(word.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0) })
    }

    /// Match the most recent spoken phrase near the current reading position.
    /// A longer phrase can recover from a skipped line; a single word stays close.
    func followPosition(transcript: String, from current: Int) -> Int? {
        let spoken = transcript.split(whereSeparator: { $0.isWhitespace }).map { Self.normalized(String($0)) }.filter { !$0.isEmpty }
        guard !spoken.isEmpty, !words.isEmpty else { return nil }
        let normalized = words.map { Self.normalized($0.text) }
        let lower = max(0, current - 4)
        let upper = min(words.count - 1, current + 70)
        guard lower <= upper else { return nil }
        for length in stride(from: min(6, spoken.count), through: 2, by: -1) {
            let phrase = Array(spoken.suffix(length))
            for end in lower...upper where end + 1 >= length {
                if Array(normalized[(end + 1 - length)...end]) == phrase { return max(current, end) }
            }
        }
        // Single-word matches may advance only to the next word, avoiding jumps
        // on repeated words such as "the", "a", and "and".
        let nearby = min(words.count - 1, current + 1)
        for index in current...nearby where normalized[index] == spoken.last { return index }
        return nil
    }
}

nonisolated enum ReadingMode: String, Codable, CaseIterable {
    case voice = "Voice"
    case autoScroll = "Auto-scroll"
    case manual = "Manual"
}

nonisolated enum PromptInk: String, Codable, CaseIterable {
    case white = "Soft white"
    case gray = "Slate gray"
    case cyan = "Soft cyan"
    case yellow = "Warm yellow"

    var title: String {
        switch self {
        case .white: "White"
        case .gray: "Gray"
        case .cyan: "Cyan"
        case .yellow: "Yellow"
        }
    }

    var rgb: (Double, Double, Double) {
        switch self {
        case .white: (0.96, 0.97, 0.99)
        case .gray: (0.63, 0.68, 0.74)
        case .cyan: (0.48, 0.89, 0.95)
        case .yellow: (1.0, 0.85, 0.43)
        }
    }

    var underlineRGB: (Double, Double, Double) {
        switch self {
        case .white: (0.96, 0.97, 0.99)
        case .gray: (0.80, 0.85, 0.91)
        case .cyan: (0.38, 0.87, 0.95)
        case .yellow: (1.0, 0.81, 0.32)
        }
    }

}

nonisolated struct ReadingPosition: Codable {
    var wordIndex: Int
    var wordProgress: Double
    var finished: Bool
}

nonisolated enum WorkspaceTab: String, Codable, CaseIterable {
    case read = "Read"
    case cards = "Cards"
    case notes = "Notes"
}

nonisolated struct WorkspaceAppearance: Codable {
    var textSize: Double
    var ink: PromptInk
    var transparency: Double
    var width: Double
    var height: Double
    var openOnHover: Bool? = nil
}

nonisolated struct CueCard: Codable, Identifiable {
    var id = UUID()
    var title = ""
    var details = ""
    var notes = ""
    var completed = false
}

nonisolated struct Chapter: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var readingPosition: ReadingPosition? = nil
    var cards: [CueCard]? = nil
    var selectedCardID: UUID? = nil
    var notes: String? = nil
    var selectedTab: WorkspaceTab? = nil
    var workspace: WorkspaceTab? = nil
}

nonisolated struct SavedSession: Codable {
    var text = "Welcome to SmartNotch.\n\nToday, let’s make something worth sharing.\n\nKeep your eyes near the camera. Speak naturally, take a breath, and make the story your own.\n\nHover over the camera notch to open your script. Click the pin to keep it open, or press Control + Option + Space to start reading."
    var speed = 150.0
    var textSize = 24.0
    var width = 580.0
    var height = 300.0
    var mode: ReadingMode = .autoScroll
    var openOnHover = true
    var voiceLocale = "en-US"
    var transparency = 0.0
    var playbackRate = 1.0
    var ink: PromptInk = .cyan
    var chapters: [Chapter]? = nil
    var activeChapterID: UUID? = nil
    var workspaceTab: WorkspaceTab? = nil
    var titleSelections: [String: UUID]? = nil
    var workspaceAppearances: [String: WorkspaceAppearance]? = nil
}

extension SavedSession {
    // Adding settings must preserve scripts saved by earlier app versions.
    nonisolated init(from decoder: any Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        chapters = try values.decodeIfPresent([Chapter].self, forKey: .chapters)
        activeChapterID = try values.decodeIfPresent(UUID.self, forKey: .activeChapterID)
        workspaceTab = try values.decodeIfPresent(WorkspaceTab.self, forKey: .workspaceTab)
        titleSelections = try values.decodeIfPresent([String: UUID].self, forKey: .titleSelections)
        workspaceAppearances = try values.decodeIfPresent([String: WorkspaceAppearance].self, forKey: .workspaceAppearances)
        text = try values.decodeIfPresent(String.self, forKey: .text) ?? text
        speed = try values.decodeIfPresent(Double.self, forKey: .speed) ?? speed
        textSize = try values.decodeIfPresent(Double.self, forKey: .textSize) ?? textSize
        width = try values.decodeIfPresent(Double.self, forKey: .width) ?? width
        height = try values.decodeIfPresent(Double.self, forKey: .height) ?? height
        mode = try values.decodeIfPresent(ReadingMode.self, forKey: .mode) ?? mode
        openOnHover = try values.decodeIfPresent(Bool.self, forKey: .openOnHover) ?? openOnHover
        voiceLocale = try values.decodeIfPresent(String.self, forKey: .voiceLocale) ?? voiceLocale
        transparency = try values.decodeIfPresent(Double.self, forKey: .transparency) ?? transparency
        playbackRate = try values.decodeIfPresent(Double.self, forKey: .playbackRate) ?? playbackRate
        if let savedInk = try values.decodeIfPresent(String.self, forKey: .ink) {
            ink = PromptInk(rawValue: savedInk) ?? .cyan
        }
    }
}

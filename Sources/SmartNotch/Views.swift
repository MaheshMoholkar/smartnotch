import SwiftUI
import AppKit

let accent = Color(red: 0.40, green: 0.91, blue: 0.76)
let editorBackground = Color(red: 0.122, green: 0.122, blue: 0.122)

struct EditorView: View {
    @Bindable var model: PromptModel

    var body: some View {
        HStack(spacing: 0) {
            ChapterSidebar(model: model)
            Divider().overlay(.white.opacity(0.06))
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text(model.activeTab.rawValue).font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if model.updates.updateAvailable {
                        UpdateAvailableButton(updates: model.updates)
                    }
                    Button { model.isSettingsPresented.toggle() } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .controlSize(.large).modifier(ControlPointer())
                    Button("Import") { model.importScript() }
                        .controlSize(.large).modifier(ControlPointer()).help("Import \(model.activeTab.rawValue.lowercased()) content")
                    Button("Export") { model.exportScript() }
                        .controlSize(.large).modifier(ControlPointer()).help("Export \(model.activeTab.rawValue.lowercased()) content")
                }.padding(.horizontal, 24).frame(height: 60)
                Divider()
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        TextField("Title", text: $model.activeChapterTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 22, weight: .semibold))
                            .accessibilityLabel("Title")
                    }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
                    Divider().padding(.horizontal, 24)
                    EditorWorkspaceContent(model: model)
                }
                HStack(spacing: 20) {
                    KeyboardShortcutRow(tab: model.activeTab)
                    Spacer(minLength: 20)
                    Button { model.togglePlayback() } label: {
                        Label(model.activeTab == .read ? (model.isStartingVoice ? "Cancel" : model.isPlaying ? "Pause" : model.mode == .manual ? "Show script" : model.finished ? "Read again" : "Start reading") : model.activeTab == .cards ? "Open cards" : "Open notes", systemImage: model.activeTab == .read ? (model.isPlaying || model.isStartingVoice ? "pause.fill" : "play.fill") : model.activeTab == .cards ? "rectangle.stack" : "note.text")
                            .frame(minWidth: 110)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 15).frame(height: 38)
                    .background(model.activeTab == .read && model.script.words.isEmpty ? Color.gray : accent, in: Capsule())
                    .foregroundStyle(.black).disabled(model.activeTab == .read && model.script.words.isEmpty)
                    .modifier(ControlPointer())
                }.controlSize(.large)
                    .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 24)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(editorBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.isSettingsPresented) {
            EditorSettingsView(model: model)
                .frame(width: 680, height: 570)
                .background(editorBackground)
                .preferredColorScheme(.dark)
        }
        .alert("SmartNotch", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct ChapterSidebar: View {
    @Bindable var model: PromptModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HeaderMenu(model: model, inEditor: true)
                Text("SmartNotch").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
            }.padding(.horizontal, 16).frame(height: 60)
            Divider()
            WorkspaceTabs(model: model).padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
            HStack {
                Text("List").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { model.addChapter() } label: {
                    Image(systemName: "plus").frame(width: 28, height: 28)
                }.buttonStyle(.plain).modifier(ControlPointer())
                    .accessibilityLabel("Add title").help("Add title")
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(model.visibleTitles) { chapter in
                        chapterRow(chapter)
                    }
                }.padding(10)
            }
        }.frame(width: 260).frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.012))
            .alert("Delete title?", isPresented: Binding(get: { model.chapterToDelete != nil }, set: { if !$0 { model.chapterToDelete = nil } })) {
                Button("Cancel", role: .cancel) { model.chapterToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let chapter = model.chapterToDelete { model.deleteChapter(chapter.id) }
                    model.chapterToDelete = nil
                }
            } message: { Text("This removes the title and its content.") }
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        let selected = model.activeChapterID == chapter.id
        return HStack(alignment: .top, spacing: 0) {
            Button { model.selectChapter(chapter.id) } label: {
                ChapterRowLabel(chapter: chapter)
            }
            .buttonStyle(.plain).modifier(ControlPointer())
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button { model.chapterToDelete = chapter } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).modifier(ControlPointer())
            .padding(.top, 7).padding(.trailing, 6)
            .disabled(model.visibleTitles.count <= 1)
            .accessibilityLabel("Delete \(chapter.title.isEmpty ? "untitled item" : chapter.title)")
            .help("Delete title")
            .opacity(model.hoveredChapterID == chapter.id ? 1 : 0)
            .allowsHitTesting(model.hoveredChapterID == chapter.id)
            .accessibilityHidden(model.hoveredChapterID != chapter.id)
        }
        .background(selected ? Color.white.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { model.hoveredChapterID = chapter.id }
            else if model.hoveredChapterID == chapter.id { model.hoveredChapterID = nil }
        }
        .contextMenu {
            Button("Delete title", role: .destructive) { model.chapterToDelete = chapter }
                .disabled(model.visibleTitles.count <= 1)
        }
    }

}

private struct ChapterRowLabel: View {
    let chapter: Chapter
    private var preview: String {
        switch chapter.workspace ?? .read {
        case .read: chapter.text
        case .notes: chapter.notes ?? ""
        case .cards: (chapter.cards ?? []).map(\.title).filter { !$0.isEmpty }.prefix(2).joined(separator: " · ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(chapter.title.isEmpty ? "Untitled" : chapter.title)
                .font(.system(size: 13, weight: .semibold)).lineLimit(2)
            if !preview.isEmpty {
                Text(preview.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .contentShape(Rectangle())
    }
}

struct AppearancePreview: View {
    let model: PromptModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Appearance preview").font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(Int(model.textSize)) pt · \(Int(model.transparency))%")
                    .font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
            }
            ZStack {
                Canvas { context, size in
                    let tile = 10.0
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.76)))
                    for row in 0..<Int(ceil(size.height / tile)) {
                        for column in 0..<Int(ceil(size.width / tile)) where (row + column).isMultiple(of: 2) {
                            let rect = CGRect(x: Double(column) * tile, y: Double(row) * tile, width: tile, height: tile)
                            context.fill(Path(rect), with: .color(Color(white: 0.9)))
                        }
                    }
                }
                Text("Welcome to\nMaheshLabs.")
                    .font(.system(size: model.textSize * 0.65, weight: .medium))
                    .foregroundStyle(Color(red: model.ink.rgb.0, green: model.ink.rgb.1, blue: model.ink.rgb.2))
                    .shadow(color: .black.opacity(model.transparency >= 50 ? 0.7 : 0), radius: 1, y: 1)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .modifier(LensGlass(cornerRadius: 10, transparency: model.transparency))
                    .padding(8)
            }
            .frame(height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }.accessibilityElement(children: .combine)
            .accessibilityLabel("Live appearance preview")
    }
}

private struct KeyboardShortcutRow: View {
    let tab: WorkspaceTab
    var body: some View {
        HStack(spacing: 14) {
            if tab == .read {
                shortcut("⌃⌥ Space", "Play/pause")
                shortcut("⌃⌥ ↑", "Previous")
                shortcut("⌃⌥ ↓", "Next")
            } else if tab == .cards {
                shortcut("⌃⌥ ↑", "Previous card")
                shortcut("⌃⌥ ↓", "Next card")
            } else {
                shortcut("⌃⌥ Space", "Open notes")
            }
            shortcut("⌃⌥ P", "Panel")
        }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tab == .read ? "Control Option Space to play or pause; Control Option Up and Down to navigate paragraphs; Control Option P to show or hide panel" : tab == .cards ? "Control Option Up and Down to navigate cards; Control Option P to show or hide panel" : "Control Option Space to open notes; Control Option P to show or hide panel")
    }

    private func shortcut(_ keys: String, _ title: String) -> some View {
        HStack(spacing: 4) {
            Text(keys).font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 5).padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            Text(title).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
        }.fixedSize()
    }
}

struct EditorSettingsView: View {
    @Bindable var model: PromptModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings").font(.system(size: 20, weight: .semibold))
                    Text("\(model.activeTab.rawValue) appearance and behavior").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.isSettingsPresented = false } label: {
                    Image(systemName: "xmark").frame(width: 28, height: 28)
                }.buttonStyle(.plain).modifier(ControlPointer()).accessibilityLabel("Close settings")
                    .keyboardShortcut(.cancelAction)
            }.padding(.horizontal, 24).padding(.vertical, 20)
            Divider()
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 18) {
                    AppearancePreview(model: model)
                    appearanceSettings
                }.frame(maxWidth: .infinity)
                workspaceSettings.frame(maxWidth: .infinity)
            }.padding(24)
            Spacer(minLength: 0)
            if !model.shortcutsAvailable {
                Text("A shortcut is in use by another app. Popup buttons remain available.")
                    .font(.caption).foregroundStyle(.orange).padding(.horizontal, 24).padding(.bottom, 12)
            }
            Divider()
            HStack {
                Spacer()
                Button("Done") { model.isSettingsPresented = false }
                    .keyboardShortcut(.defaultAction).controlSize(.large).modifier(ControlPointer())
            }.padding(.horizontal, 24).padding(.vertical, 14)
        }
    }

    @ViewBuilder private var workspaceSettings: some View {
        if model.activeTab == .read {
            readingSettings
        } else {
            EditorSettingsSection(model.activeTab.rawValue.uppercased()) {
                HStack {
                    Text("Open on hover")
                    Spacer()
                    Toggle("Open on hover", isOn: $model.openOnHover)
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini).modifier(ControlPointer())
                }
                Text(model.activeTab == .cards ? "Use the arrow buttons to move between cards, or focus the popup and use arrow keys. Space marks a card complete." : "Choose Edit notes in the popup to start typing. Done or Escape finishes editing.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var readingSettings: some View {
        EditorSettingsSection("READING") {
            HStack { Text("Mode"); Spacer(); ReadingModeMenu(model: model) }
            if model.mode == .voice {
                Picker("Language", selection: $model.voiceLocale) {
                    Text("English (US)").tag("en-US")
                    Text("English (India)").tag("en-IN")
                    Text("Hindi (India)").tag("hi-IN")
                }
            }
            HStack {
                Text("Open on hover")
                Spacer()
                Toggle("Open on hover", isOn: $model.openOnHover)
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini).modifier(ControlPointer())
            }
            settingLabel("Base pace", value: "\(Int(model.speed)) WPM")
            Slider(value: $model.speed, in: 60...240, step: 5).accessibilityLabel("Reading speed").modifier(SliderPointer())
            HStack { Text("Playback speed"); Spacer(); PlaybackSpeedMenu(model: model) }
        }
    }

    private var appearanceSettings: some View {
        EditorSettingsSection("APPEARANCE") {
            settingLabel("Text size", value: "\(Int(model.textSize)) pt")
            Slider(value: $model.textSize, in: 18...36, step: 1).accessibilityLabel("Prompter text size").modifier(SliderPointer())
            HStack { Text("Text color"); Spacer(); FontColorMenu(model: model) }
            settingLabel("Transparency", value: "\(Int(model.transparency))%")
            Slider(value: $model.transparency, in: 0...100, step: 5).accessibilityLabel("Background transparency").modifier(SliderPointer())
            HStack { Text("Popup width"); Spacer(); PopupWidthMenu(model: model) }
        }
    }

    private func settingLabel(_ label: String, value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).monospacedDigit().foregroundStyle(.secondary) }
    }
}

struct EditorSettingsSection<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            content
        }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StatusOptionsView: View {
    private enum Option: Hashable {
        case panel, hover, editor, updates, quit
    }

    @Bindable var model: PromptModel
    @FocusState private var focusedOption: Option?
    let checkForUpdates: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            row(.panel, model.isVisible && model.isExpanded ? "Hide panel" : "Show panel") { model.togglePopup() }
            divider
            row(.hover, "Open on hover", checked: model.openOnHover) { model.openOnHover.toggle() }
                .accessibilityValue(model.openOnHover ? "On" : "Off")
            divider
            row(.editor, "Open editor") { model.onEditor?() }
            divider
            row(.updates, "Check for Updates…", action: checkForUpdates)
            divider
            row(.quit, "Quit SmartNotch", shortcut: "⌘Q") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(6)
        .font(.system(size: 14))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(LensGlass(cornerRadius: 14, transparency: 0))
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Divider().overlay(.white.opacity(0.1)).padding(.leading, 28).padding(.trailing, 9)
    }

    private func row(_ option: Option, _ title: String, checked: Bool = false, shortcut: String? = nil,
                     action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").opacity(checked ? 1 : 0)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(title)
                Spacer(minLength: 0)
                if let shortcut { Text(shortcut).foregroundStyle(.secondary).accessibilityHidden(true) }
            }
            .padding(.horizontal, 8)
            .frame(height: 31)
            .contentShape(Rectangle())
        }
        .buttonStyle(StatusOptionButtonStyle(isFocused: focusedOption == option))
        .focused($focusedOption, equals: option)
        .focusEffectDisabled()
        .modifier(ControlPointer())
    }
}

private struct StatusOptionButtonStyle: ButtonStyle {
    let isFocused: Bool
    private var isHovered = State<Bool>(initialValue: false)

    func makeBody(configuration: Configuration) -> some View {
        let isHighlighted = isFocused || isHovered.wrappedValue
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.19 : isHighlighted ? 0.11 : 0),
                        in: RoundedRectangle(cornerRadius: 6))
            .onHover { isHovered.wrappedValue = $0 }
    }
}

struct HeaderMenu: View {
    @Bindable var model: PromptModel
    var inEditor = false

    var body: some View {
        Menu {
            Button(model.isVisible && model.isExpanded ? "Hide panel" : "Show panel") { model.togglePopup() }
            Toggle("Open on hover", isOn: $model.openOnHover)
            Divider()
            if inEditor {
                Button("Hide editor") { NSApp.keyWindow?.orderOut(nil) }
            } else {
                Button("Open editor") { model.onEditor?() }
            }
            Divider()
            Button(model.updates.updateAvailable ? "Update available…" : "Check for Updates…") { model.updates.check() }
                .disabled(!model.updates.canCheck)
            Divider()
            Button("Quit SmartNotch") { NSApp.terminate(nil) }
        } label: {
            Group {
                if let logo = SmartNotchLogo.image {
                    Image(nsImage: logo)
                        .resizable()
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .frame(width: 26, height: 28)
            .background(.white.opacity(0.06), in: Capsule())
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .focusEffectDisabled()
            .accessibilityLabel("SmartNotch menu").help("SmartNotch menu")
            .modifier(ControlPointer())
    }
}

struct TonalIconStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.06), in: Capsule())
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct PopupAppearanceControls: View {
    @Bindable var model: PromptModel

    private var fontSize: some View {
        HStack(spacing: 4) {
            Button { model.adjustTextSize(by: -1) } label: {
                Image(systemName: "minus").frame(width: 26, height: 28)
            }.modifier(ControlPointer()).disabled(model.textSize <= 18).accessibilityLabel("Decrease font size")
            Spacer(minLength: 0)
            Text("\(Int(model.textSize)) pt").monospacedDigit().frame(width: 32)
            Spacer(minLength: 0)
            Button { model.adjustTextSize(by: 1) } label: {
                Image(systemName: "plus").frame(width: 26, height: 28)
            }.modifier(ControlPointer()).disabled(model.textSize >= 36).accessibilityLabel("Increase font size")
        }.buttonStyle(TonalIconStyle())
            .accessibilityElement(children: .contain).accessibilityLabel("Font size")
    }

    var body: some View {
        VStack(spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    if model.activeTab == .read {
                        ReadingModeMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                        PlaybackSpeedMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                    }
                    FontColorMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                    PopupWidthMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                    fontSize.frame(maxWidth: .infinity)
                }
                VStack(spacing: 8) {
                    if model.activeTab == .read {
                        HStack(spacing: 8) {
                            ReadingModeMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                            PlaybackSpeedMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                        }
                    }
                    HStack(spacing: 8) {
                        FontColorMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                        PopupWidthMenu(model: model, fillsWidth: true).frame(maxWidth: .infinity)
                        fontSize.frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled").accessibilityHidden(true)
                Text("Transparency").foregroundStyle(.secondary)
                Slider(value: $model.transparency, in: 0...100, step: 5)
                    .accessibilityLabel("Panel background transparency").modifier(SliderPointer())
                Text("\(Int(model.transparency))%").monospacedDigit().frame(width: 30, alignment: .trailing)
            }
        }.font(.system(size: 11)).controlSize(.small).tint(.white.opacity(0.65))
            .padding(10)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain).accessibilityLabel("Reading and appearance settings")
    }
}

struct FontColorMenu: View {
    @Bindable var model: PromptModel
    var fillsWidth = false
    var body: some View {
        Menu {
            ForEach(PromptInk.allCases, id: \.self) { ink in
                Button { model.ink = ink } label: {
                    if model.ink == ink { Label(ink.title, systemImage: "checkmark") }
                    else { Text(ink.title) }
                }
            }
        } label: {
            CapsuleControlLabel(title: model.ink.title, fillsWidth: fillsWidth)
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize(horizontal: !fillsWidth, vertical: true)
            .accessibilityLabel("Text color").modifier(ControlPointer())
    }
}

struct PopupWidthMenu: View {
    @Bindable var model: PromptModel
    var fillsWidth = false
    private let widths: [Double] = [420, 580, 680]

    private func title(for width: Double) -> String {
        switch width {
        case 420: "Narrow"
        case 580: "Normal"
        case 680: "Wide"
        default: "Custom"
        }
    }

    var body: some View {
        Menu {
            ForEach(widths, id: \.self) { width in
                Button { model.width = width } label: {
                    if model.width == width { Label(title(for: width), systemImage: "checkmark") }
                    else { Text(title(for: width)) }
                }
            }
            if !widths.contains(model.width) {
                Label("Custom (\(Int(model.width)))", systemImage: "checkmark")
            }
        } label: {
            CapsuleControlLabel(title: title(for: model.width), fillsWidth: fillsWidth)
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize(horizontal: !fillsWidth, vertical: true)
            .accessibilityLabel("Popup width").modifier(ControlPointer())
    }
}

struct CapsuleControlLabel: View {
    let title: String
    var symbol: String? = nil
    var expanded = false
    var fillsWidth = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(title).monospacedDigit()
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }.font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .frame(maxWidth: fillsWidth ? .infinity : nil).frame(height: 30)
            .background(Color.white.opacity(expanded ? 0.13 : 0.06), in: Capsule())
            .contentShape(Capsule())
    }
}

struct ReadingModeMenu: View {
    @Bindable var model: PromptModel
    var fillsWidth = false
    var body: some View {
        Menu {
            ForEach(ReadingMode.allCases, id: \.self) { mode in
                Button { model.mode = mode } label: {
                    if model.mode == mode { Label(mode.rawValue, systemImage: "checkmark") }
                    else { Text(mode.rawValue) }
                }
            }
        } label: {
            CapsuleControlLabel(title: model.mode == .autoScroll ? "Auto" : model.mode.rawValue, fillsWidth: fillsWidth)
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize(horizontal: !fillsWidth, vertical: true)
            .accessibilityLabel("Reading mode").modifier(ControlPointer())
    }
}

struct PlaybackSpeedMenu: View {
    @Bindable var model: PromptModel
    var fillsWidth = false
    var body: some View {
        Menu {
            ForEach([0.5, 0.75, 1, 1.25, 1.5, 1.75, 2], id: \.self) { rate in
                Button {
                    model.playbackRate = rate
                } label: {
                    if abs(model.playbackRate - rate) < 0.001 {
                        Label(rate == 1 ? "Normal (1×)" : "\(rate.formatted())×", systemImage: "checkmark")
                    } else {
                        Text(rate == 1 ? "Normal (1×)" : "\(rate.formatted())×")
                    }
                }
            }
        } label: {
            CapsuleControlLabel(title: model.playbackRateLabel, fillsWidth: fillsWidth)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize(horizontal: !fillsWidth, vertical: true)
        .modifier(ControlPointer())
        .accessibilityLabel("Playback speed").help("Playback speed · \(Int(model.effectiveSpeed)) words per minute")
        .disabled(model.mode != .autoScroll)
    }
}

struct ControlPointer: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    func body(content: Content) -> some View {
        content.overlay(CursorRegion(cursor: isEnabled ? .pointingHand : .arrow))
    }
}

/// Native cursor rectangles survive AppKit cursor resets in nonactivating panels.
struct CursorRegion: NSViewRepresentable {
    let cursor: NSCursor

    static func cursor(at windowPoint: NSPoint, in view: NSView) -> NSCursor? {
        let point = view.convert(windowPoint, from: nil)
        guard !view.isHidden, view.alphaValue > 0,
              view.bounds.contains(point), view.visibleRect.contains(point) else { return nil }
        for child in view.subviews.reversed() {
            if let cursor = cursor(at: windowPoint, in: child) { return cursor }
        }
        return (view as? RegionView)?.cursor
    }

    final class RegionView: NSView {
        var cursor = NSCursor.arrow
        private var cursorTrackingArea: NSTrackingArea?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func resetCursorRects() { addCursorRect(bounds, cursor: cursor) }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let cursorTrackingArea { removeTrackingArea(cursorTrackingArea) }
            let area = NSTrackingArea(rect: .zero,
                                      options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
                                      owner: self)
            addTrackingArea(area)
            cursorTrackingArea = area
        }

        override func cursorUpdate(with event: NSEvent) { cursor.set() }
        override func mouseEntered(with event: NSEvent) { cursor.set() }
        override func mouseMoved(with event: NSEvent) { cursor.set() }
        override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }
    }

    func makeNSView(context: Context) -> RegionView { RegionView() }
    func updateNSView(_ view: RegionView, context: Context) {
        view.cursor = cursor
        view.window?.invalidateCursorRects(for: view)
    }
}

struct SliderPointer: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    func body(content: Content) -> some View {
        content.overlay(CursorRegion(cursor: isEnabled ? .resizeLeftRight : .arrow))
    }
}

/// Fixed charcoal avoids active/inactive glass changes; only the user's slider fades it.
struct LensGlass: ViewModifier {
    var cornerRadius = 20.0
    var transparency = 35.0
    private var backgroundOpacity: Double { 1 - min(100, max(0, transparency)) / 100 }

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(editorBackground).opacity(backgroundOpacity)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04), .white.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
                .opacity(backgroundOpacity)
                .allowsHitTesting(false)
        }
    }
}

struct PanelView: View {
    @Bindable var model: PromptModel
    let hide: () -> Void
    var isPreview = false

    var body: some View {
        VStack(spacing: 0) {
            if model.isExpanded || isPreview {
                expandedBody
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "viewfinder")
                    Text("SmartNotch").font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }.frame(maxWidth: .infinity).frame(height: 26).background(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22))
        .foregroundStyle(.white).preferredColorScheme(.dark)
    }

    private var expandedBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                HeaderMenu(model: model)
                Text("SmartNotch").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1).fixedSize()
                Spacer(minLength: 6)
                PopupWorkspaceTabs(model: model)
                Spacer(minLength: 6)
                if model.updates.updateAvailable {
                    UpdateAvailableButton(updates: model.updates, compact: true)
                }
                panelButton(model.isPinned ? "pin.fill" : "pin", label: model.isPinned ? "Unpin panel" : "Pin panel") { model.isPinned.toggle() }
                    .foregroundStyle(model.isPinned ? accent : .white.opacity(0.75))
                    .disabled(model.isPopupEditing)
                panelButton("square.and.pencil", label: "Edit content") { model.onEditor?() }
                panelButton("xmark", label: "Close popup", action: hide)
            }.padding(.horizontal, 16).frame(height: 44)

            Group {
                switch model.activeTab {
                case .read: ReaderView(model: model).padding(.horizontal, 18)
                case .cards: PopupCardsView(model: model)
                case .notes: PopupNotesView(model: model)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)

            popupControls.padding(.horizontal, 20).padding(.top, 2)

            if model.isConfigurationExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONFIGURE").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                    PopupAppearanceControls(model: model)
                }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20).padding(.top, 10)
                    .onGeometryChange(for: Double.self) { geometry in
                        geometry.size.height
                    } action: { height in
                        if abs(model.configurationContentHeight - height) > 0.5 {
                            model.configurationContentHeight = height
                        }
                    }
            }

            if model.activeTab == .cards && model.isCardListExpanded {
                PopupCardList(model: model).frame(height: model.cardListHeight)
            }

            if model.isChaptersExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIST").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(model.visibleTitles.enumerated()), id: \.element.id) { index, chapter in
                                Button { model.selectChapter(chapter.id) } label: {
                                    HStack(spacing: 8) {
                                        Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                                        Text(chapter.title.isEmpty ? "Untitled" : chapter.title).lineLimit(1)
                                        Spacer()
                                        if chapter.id == model.activeChapterID { Image(systemName: "checkmark").foregroundStyle(accent) }
                                    }.font(.system(size: 12)).padding(.horizontal, 10).frame(height: 36)
                                        .background(chapter.id == model.activeChapterID ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).modifier(ControlPointer())
                                    .accessibilityAddTraits(chapter.id == model.activeChapterID ? .isSelected : [])
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 10)
                    .frame(height: model.chapterListHeight)
            }

            Capsule().fill(model.isResizeHovered || model.isResizing ? accent : .white.opacity(0.3))
                .frame(width: model.isResizeHovered || model.isResizing ? 64 : 42, height: 5)
                .frame(maxWidth: .infinity).frame(height: 14)
                .background {
                    if model.isResizeHovered || model.isResizing {
                        RoundedRectangle(cornerRadius: 9).fill(accent.opacity(0.12)).padding(.horizontal, 12)
                    }
                }
                .background(CursorRegion(cursor: model.isResizing ? .closedHand : .openHand))
                .contentShape(Rectangle()).help("Drag down to expand · double-click to reset")
                .accessibilityLabel("Drag to resize popup")
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        model.isResizeHovered = true
                        (model.isResizing ? NSCursor.closedHand : NSCursor.openHand).set()
                    case .ended:
                        model.isResizeHovered = false
                        if !model.isResizing { NSCursor.arrow.set() }
                    }
                }
                .onTapGesture(count: 2) { model.height = 300 }
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        model.resizePopup(by: value.translation.height)
                        NSCursor.closedHand.set()
                    }
                    .onEnded { _ in
                        model.endResizing()
                        (model.isResizeHovered ? NSCursor.openHand : NSCursor.arrow).set()
                    })
        }
        .modifier(LensGlass(cornerRadius: 22, transparency: model.transparency))
        // Nonzero backing alpha keeps the WindowServer input region alive at
        // 100% glass transparency without dimming the script or controls.
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
    }

    private var popupControls: some View {
        HStack(spacing: 7) {
            HStack(spacing: 7) {
                panelButton("gearshape", label: "Configure \(model.activeTab.rawValue)") { model.isConfigurationExpanded.toggle() }
                    .foregroundStyle(model.isConfigurationExpanded ? accent : .white)
                    .accessibilityValue(model.isConfigurationExpanded ? "Expanded" : "Collapsed")
                Spacer(minLength: 0)
                if model.activeTab == .read {
                    panelButton("arrow.counterclockwise", label: "Restart") { model.reset() }
                    panelButton("backward.end.fill", label: "Previous paragraph") { model.jump(forward: false) }
                } else if model.activeTab == .cards {
                    panelButton("chevron.left", label: "Previous card") { model.moveCard(forward: false) }
                        .disabled(model.activeCardIndex == 0 || model.cards.isEmpty || model.isPopupEditing)
                }
            }.frame(maxWidth: .infinity)
            if model.activeTab == .read {
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.isPlaying || model.isStartingVoice ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .semibold)).frame(width: 46, height: 36)
                        .foregroundStyle(.black).background(accent, in: Capsule())
                }.buttonStyle(.plain).modifier(ControlPointer())
                    .accessibilityLabel(model.isStartingVoice ? "Cancel voice startup" : model.isPlaying ? "Pause" : "Play")
                    .disabled(model.script.words.isEmpty)
            } else if model.activeTab == .notes || model.isPopupEditing {
                Button { model.isPopupEditing.toggle() } label: {
                    Label(model.isPopupEditing ? "Done" : "Edit notes", systemImage: model.isPopupEditing ? "checkmark" : "pencil")
                        .font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).frame(height: 32)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }.buttonStyle(.plain).modifier(ControlPointer())
            } else {
                Button {
                    model.isCardListExpanded.toggle()
                    if model.isCardListExpanded { model.isChaptersExpanded = false }
                } label: {
                    HStack(spacing: 5) {
                        Text(model.cards.isEmpty ? "0 / 0" : "\(model.activeCardIndex + 1) / \(model.cards.count)").monospacedDigit()
                        Image(systemName: model.isCardListExpanded ? "chevron.up" : "chevron.down").font(.system(size: 8))
                    }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 10).frame(minWidth: 46, minHeight: 36)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }.buttonStyle(.plain).modifier(ControlPointer()).disabled(model.cards.isEmpty)
                    .accessibilityLabel("Card \(model.cards.isEmpty ? 0 : model.activeCardIndex + 1) of \(model.cards.count)")
                    .help("Choose a card")
            }
            HStack(spacing: 7) {
                if model.activeTab == .read {
                    panelButton("forward.end.fill", label: "Next paragraph") { model.jump(forward: true) }
                } else if model.activeTab == .cards {
                    panelButton("chevron.right", label: "Next card") { model.moveCard(forward: true) }
                        .disabled(model.activeCardIndex + 1 >= model.cards.count || model.isPopupEditing)
                }
                Spacer(minLength: 0)
                panelButton("list.bullet", label: "List") {
                    model.isChaptersExpanded.toggle()
                    if model.isChaptersExpanded { model.isCardListExpanded = false }
                }
                    .foregroundStyle(model.isChaptersExpanded ? accent : .white)
                    .accessibilityValue(model.isChaptersExpanded ? "Expanded" : "Collapsed")
            }.frame(maxWidth: .infinity)
        }
    }

    private func panelButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                .frame(width: 34, height: 32).contentShape(Rectangle())
        }.buttonStyle(TonalIconStyle()).help(label).accessibilityLabel(label).modifier(ControlPointer())
    }
}

struct UpdateAvailableButton: View {
    let updates: AppUpdates
    var compact = false

    var body: some View {
        Button { updates.check() } label: {
            ViewThatFits(in: .horizontal) {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .fixedSize()
                Image(systemName: "arrow.down.circle.fill").frame(width: 28)
            }
            .font(.system(size: compact ? 11 : 12, weight: .semibold))
            .padding(.horizontal, compact ? 8 : 12)
            .frame(height: compact ? 28 : 32)
            .background(accent.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(accent.opacity(0.3), lineWidth: 0.7))
            .foregroundStyle(accent)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).modifier(ControlPointer())
        .disabled(!updates.canCheck)
        .accessibilityLabel("Update available")
        .accessibilityValue(updates.availableVersion.map { "SmartNotch \($0)" } ?? "")
        .help("SmartNotch \(updates.availableVersion ?? "") is available. View release notes and install when you’re ready.")
    }
}

import AppKit
import SwiftUI

private extension PromptModel {
    var workspaceColor: Color { Color(red: ink.rgb.0, green: ink.rgb.1, blue: ink.rgb.2) }
    var workspaceTextColor: NSColor { NSColor(srgbRed: ink.rgb.0, green: ink.rgb.1, blue: ink.rgb.2, alpha: 1) }
}

struct EditorWorkspaceContent: View {
    @Bindable var model: PromptModel

    var body: some View {
        switch model.activeTab {
        case .read:
            VStack(spacing: 0) {
                TextEditor(text: $model.text).font(.system(size: 19)).lineSpacing(8)
                    .scrollContentBackground(.hidden).padding(.horizontal, 20).padding(.vertical, 12)
                    .accessibilityLabel("Reading content")
                Divider().padding(.horizontal, 24)
                HStack {
                    Text("\(model.script.words.count) words · ~\(model.durationLabel) reading time")
                    Spacer()
                }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 14)
            }
        case .cards: EditorCardsView(model: model)
        case .notes:
            TextEditor(text: $model.notes).font(.system(size: 17)).lineSpacing(6)
                .scrollContentBackground(.hidden).padding(.horizontal, 20).padding(.vertical, 12)
                .accessibilityLabel("Title notes")
        }
    }
}

struct WorkspaceTabs: View {
    @Bindable var model: PromptModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                Button { model.activeTab = tab } label: {
                    Text(tab.rawValue).font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background(model.activeTab == tab ? Color.white.opacity(0.13) : .clear, in: Capsule())
                        .contentShape(Capsule())
                }.buttonStyle(.plain).modifier(ControlPointer())
                    .foregroundStyle(model.activeTab == tab ? .white : .white.opacity(0.6))
                    .accessibilityAddTraits(model.activeTab == tab ? .isSelected : [])
            }
        }.padding(3).background(Color.white.opacity(0.04), in: Capsule())
            .accessibilityElement(children: .contain).accessibilityLabel("Workspace tabs")
    }
}

struct PopupWorkspaceTabs: View {
    @Bindable var model: PromptModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            WorkspaceTabs(model: model).frame(width: 192).fixedSize()
            Menu {
                ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                    Button { model.activeTab = tab } label: {
                        if model.activeTab == tab { Label(tab.rawValue, systemImage: "checkmark") }
                        else { Text(tab.rawValue) }
                    }
                }
            } label: {
                CapsuleControlLabel(title: model.activeTab.rawValue)
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
                .fixedSize().modifier(ControlPointer()).accessibilityLabel("Workspace tab")
        }
    }
}

struct EditorCardsView: View {
    @Bindable var model: PromptModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("\(model.cards.count) cards").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.addCard() } label: { Image(systemName: "plus").frame(width: 28, height: 28) }
                        .buttonStyle(.plain).modifier(ControlPointer()).accessibilityLabel("Add card")
                }.padding(.horizontal, 12).padding(.vertical, 8)
                Divider()
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(model.cards.enumerated()), id: \.element.id) { index, card in
                            Button { model.selectCard(card.id) } label: {
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: card.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(card.completed ? accent : .secondary)
                                    Text(card.title.isEmpty ? "Card \(index + 1)" : card.title).lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.font(.system(size: 12)).padding(10)
                                    .background(model.activeCard?.id == card.id ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).modifier(ControlPointer())
                                .accessibilityAddTraits(model.activeCard?.id == card.id ? .isSelected : [])
                        }
                    }.padding(8)
                }
            }.frame(width: 180)
                .focusable().focusEffectDisabled()
                .onKeyPress(.upArrow) { model.moveCard(forward: false); return .handled }
                .onKeyPress(.downArrow) { model.moveCard(forward: true); return .handled }
            Divider()
            if let card = model.activeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Card title", text: $model.cardTitle)
                            .textFieldStyle(.plain).font(.system(size: 19, weight: .semibold))
                            .accessibilityLabel("Card title")
                        Button { model.toggleCardCompleted() } label: {
                            Image(systemName: card.completed ? "checkmark.circle.fill" : "circle")
                        }.buttonStyle(.plain).modifier(ControlPointer()).foregroundStyle(card.completed ? accent : .secondary)
                            .accessibilityLabel(card.completed ? "Mark card incomplete" : "Mark card complete")
                        Button { model.cardToDelete = card.id } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).modifier(ControlPointer()).accessibilityLabel("Delete card")
                    }
                    Divider()
                    Text("DETAILS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    TextEditor(text: $model.cardDetails).font(.system(size: 16)).scrollContentBackground(.hidden)
                        .accessibilityLabel("Card details")
                    Divider()
                    Text("NOTES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    TextEditor(text: $model.cardNotes).font(.system(size: 15)).scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 130).accessibilityLabel("Card notes")
                }.padding(20)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack").font(.system(size: 26)).foregroundStyle(.secondary)
                    Text("Add your first card").font(.system(size: 16, weight: .semibold))
                    Text("Talking points, questions, steps, or reminders.").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Add card") { model.addCard() }.modifier(ControlPointer())
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Delete card?", isPresented: Binding(get: { model.cardToDelete != nil }, set: { if !$0 { model.cardToDelete = nil } })) {
            Button("Cancel", role: .cancel) { model.cardToDelete = nil }
            Button("Delete", role: .destructive) {
                if let id = model.cardToDelete { model.deleteCard(id) }
                model.cardToDelete = nil
            }
        } message: { Text("This removes the card, its details, and its notes.") }
    }
}

struct PopupCardsView: View {
    @Bindable var model: PromptModel

    var body: some View {
        if let card = model.activeCard {
            if model.isPopupEditing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTES · \(card.title.isEmpty ? "Card \(model.activeCardIndex + 1)" : card.title)")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                    PopupTextEditor(text: $model.cardNotes, editing: true, textSize: max(15, model.textSize * 0.75), color: model.workspaceTextColor, onDone: { model.isPopupEditing = false })
                }.padding(.horizontal, 22).padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text(card.title.isEmpty ? "Card \(model.activeCardIndex + 1)" : card.title)
                                .font(.system(size: model.textSize, weight: .semibold)).foregroundStyle(model.workspaceColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button { model.toggleCardCompleted() } label: {
                                Image(systemName: card.completed ? "checkmark.circle.fill" : "circle").frame(width: 28, height: 28)
                            }.buttonStyle(.plain).modifier(ControlPointer()).foregroundStyle(card.completed ? accent : .secondary)
                                .accessibilityLabel(card.completed ? "Mark card incomplete" : "Mark card complete")
                        }
                        if !card.details.isEmpty { Text(card.details).font(.system(size: max(15, model.textSize * 0.75))).foregroundStyle(model.workspaceColor).textSelection(.disabled) }
                        Divider()
                        HStack {
                            Text("NOTES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Button { model.isPopupEditing = true } label: { Label("Edit notes", systemImage: "pencil") }
                                .font(.system(size: 11)).buttonStyle(.plain).modifier(ControlPointer())
                        }
                        if !card.notes.isEmpty { Text(card.notes).font(.system(size: 14)).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.vertical, 12)
                }
            }
        } else {
            VStack(spacing: 12) {
                Text("No cards yet").font(.system(size: 17, weight: .semibold))
                Button("Add a card") { model.addCard(); model.onEditor?() }.modifier(ControlPointer())
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PopupCardList: View {
    @Bindable var model: PromptModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CARDS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 10)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(model.cards.enumerated()), id: \.element.id) { index, card in
                        Button { model.selectCard(card.id) } label: {
                            HStack(spacing: 8) {
                                Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                                Text(card.title.isEmpty ? "Card \(index + 1)" : card.title).lineLimit(1)
                                Spacer()
                                if card.completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                                if model.activeCard?.id == card.id { Image(systemName: "chevron.right").foregroundStyle(accent) }
                            }.font(.system(size: 12)).padding(.horizontal, 10).frame(height: 36)
                                .background(model.activeCard?.id == card.id ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).modifier(ControlPointer())
                    }
                }
            }
        }.padding(.horizontal, 16).padding(.top, 10)
    }
}

struct PopupNotesView: View {
    @Bindable var model: PromptModel

    var body: some View {
        if model.isPopupEditing {
            PopupTextEditor(text: $model.notes, editing: true, textSize: model.textSize, color: model.workspaceTextColor, onDone: { model.isPopupEditing = false })
                .padding(.horizontal, 22).padding(.vertical, 12)
        } else {
            ScrollView {
                Text(model.notes.isEmpty ? "Use Edit notes to start writing." : model.notes)
                    .font(.system(size: model.textSize))
                    .foregroundStyle(model.notes.isEmpty ? Color.secondary : model.workspaceColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.vertical, 12)
            }
        }
    }
}

/// Typing is enabled deliberately; Escape returns control to the meeting app.
struct PopupTextEditor: NSViewRepresentable {
    @Binding var text: String
    var editing: Bool
    var textSize: Double
    var color: NSColor = .white
    var onDone: () -> Void

    final class TextView: NSTextView {
        var onDone: (() -> Void)?
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { onDone?() } else { super.keyDown(with: event) }
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self, isEditable, let window else { return }
                window.makeFirstResponder(self)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PopupTextEditor
        init(_ parent: PopupTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = TextView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        editor.isRichText = false
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainerInset = NSSize(width: 2, height: 8)
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Popup notes editor")
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? TextView else { return }
        context.coordinator.parent = self
        if editor.string != text { editor.string = text }
        editor.font = .systemFont(ofSize: textSize)
        editor.textColor = color
        editor.insertionPointColor = .white
        editor.isEditable = editing
        editor.isSelectable = editing
        editor.onDone = onDone
        if editing, let window = editor.window, window.firstResponder !== editor { window.makeFirstResponder(editor) }
    }
}

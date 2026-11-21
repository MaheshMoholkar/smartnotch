import AppKit
import Carbon
import SwiftUI

enum SmartNotchLogo {
    static let image = Bundle.main.url(forResource: "SmartNotchLogo", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
}

final class PromptPanel: NSPanel {
    var allowsKeyboardInput = false
    var handleWorkspaceKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { allowsKeyboardInput }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleWorkspaceKey?(event) == true { return }
        if event.type == .scrollWheel,
           let reader = findReader(in: contentView),
           reader.convert(reader.bounds, to: nil).contains(event.locationInWindow) {
            // Preserve scrolling over transparent reader content, but leave
            // the chapter list and other controls to their own event handlers.
            reader.scrollWheel(with: event)
            return
        }
        super.sendEvent(event)
        if [.mouseMoved, .cursorUpdate, .mouseEntered, .mouseExited, .leftMouseDragged].contains(event.type) {
            updatePointerCursor(at: event.locationInWindow)
        }
    }

    func updatePointerCursor(at point: NSPoint) {
        if let contentView, let cursor = CursorRegion.cursor(at: point, in: contentView) {
            cursor.set()
        } else if editableTextView(at: point, in: contentView) != nil {
            NSCursor.iBeam.set()
        } else if let reader = findReader(in: contentView), reader.convert(reader.bounds, to: nil).contains(point) {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func editableTextView(at point: NSPoint, in view: NSView?) -> NSTextView? {
        guard let view, !view.isHidden, view.bounds.contains(view.convert(point, from: nil)) else { return nil }
        if let text = view as? NSTextView, text.isEditable { return text }
        for child in view.subviews {
            if let text = editableTextView(at: point, in: child) { return text }
        }
        return nil
    }

    private func findReader(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let reader = view as? NSScrollView, reader.identifier?.rawValue == "prompt-reader" { return reader }
        for child in view.subviews {
            if let reader = findReader(in: child) { return reader }
        }
        return nil
    }
}

final class PanelController {
    let model: PromptModel
    let panel: PromptPanel
    private var pointerMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var isMenuTracking = false
    private var waitingForNotchExit = false
    private var menuObservers: [NSObjectProtocol] = []
    private var pinnedBeforeEditing = false

    init(model: PromptModel) {
        self.model = model
        panel = PromptPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "SmartNotch · Camera panel"
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: PanelView(model: model, hide: { [weak self] in self?.dismiss() }))
        host.sizingOptions = []
        panel.contentView = host
        model.onReveal = { [weak self] in self?.reveal() }
        model.onDismiss = { [weak self] in self?.dismiss() }
        model.onLayoutChange = { [weak self] in self?.layout() }
        model.onPopupEditingChange = { [weak self] editing in
            guard let self else { return }
            if editing {
                pinnedBeforeEditing = model.isPinned
                model.isPinned = true
                panel.allowsKeyboardInput = true
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.makeFirstResponder(nil)
                panel.resignKey()
                model.isPinned = pinnedBeforeEditing
                panel.allowsKeyboardInput = model.activeTab != .read
            }
        }
        panel.handleWorkspaceKey = { [weak model] event in
            guard let model else { return false }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard modifiers.isEmpty else { return false }
            if event.keyCode == kVK_Escape, model.isPopupEditing {
                model.isPopupEditing = false
                return true
            }
            guard model.activeTab == .cards, !model.isPopupEditing else { return false }
            switch Int(event.keyCode) {
            case kVK_LeftArrow, kVK_UpArrow: model.moveCard(forward: false)
            case kVK_RightArrow, kVK_DownArrow: model.moveCard(forward: true)
            case kVK_Space: model.toggleCardCompleted()
            default: return false
            }
            return true
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
        // React directly to movement, including dragging against the top edge.
        // Global mouse monitoring requires no keyboard/accessibility access.
        let movements: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: movements, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPointer() }
        }) { pointerMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: movements, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.checkPointer() }
            return event
        }) { pointerMonitors.append(local) }
        for (name, tracking) in [(NSMenu.didBeginTrackingNotification, true), (NSMenu.didEndTrackingNotification, false)] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isMenuTracking = tracking }
            })
        }
        layout()
    }

    private var cameraScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first
    }

    private func menuBarInset(on screen: NSScreen) -> CGFloat {
        max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
    }

    private func hotspot(on screen: NSScreen) -> CGRect {
        PanelGeometry.hotspot(frame: screen.frame, safeTop: screen.safeAreaInsets.top,
                              notchWidth: model.cameraCutoutWidth, menuBarInset: menuBarInset(on: screen))
    }

    func layout() {
        panel.allowsKeyboardInput = model.activeTab != .read || model.isPopupEditing
        guard model.isVisible, let screen = cameraScreen else { panel.orderOut(nil); return }
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        model.cameraCutoutWidth = screen.safeAreaInsets.top > 0
            ? (!left.isEmpty && !right.isEmpty ? max(0, right.minX - left.maxX) : 180) : 0
        let expanded = model.isExpanded
        if !expanded, screen.safeAreaInsets.top > 0 {
            // The collapsed panel is invisible; only the notch is the hover target.
            panel.orderOut(nil)
            return
        }
        let width = min(expanded ? model.width : 210, screen.frame.width - 32)
        let requestedHeight = model.expandedPopupHeight - screen.safeAreaInsets.top
        let height = min(expanded ? requestedHeight : 26, screen.visibleFrame.height - 32)
        // Keep the actual window below the menu bar, including its input region.
        let rect = PanelGeometry.panelFrame(screen: screen.frame, width: width, height: height,
                                            menuBarInset: menuBarInset(on: screen))
        // Opening, closing, and dragging all update immediately.
        panel.setFrame(rect, display: true)
        panel.orderFrontRegardless()
    }

    func reveal() {
        waitingForNotchExit = false
        model.isVisible = true
        model.isExpanded = true
        panel.alphaValue = 1
        layout()
    }

    func hide() {
        model.pause()
        model.isVisible = false
        model.isPinned = false
        collapse()
    }

    private func dismiss() {
        model.dismissPopup()
        NSCursor.arrow.set()
        collapse()
    }

    func dismissForEditing() {
        if let screen = cameraScreen {
            waitingForNotchExit = PanelGeometry.isOverNotch(NSEvent.mouseLocation, hotspot: hotspot(on: screen))
        }
        model.dismissPopup()
        NSCursor.arrow.set()
        collapse()
    }

    private func collapse() {
        model.collapsePopup()
        panel.orderOut(nil)
        layout()
    }

    func toggle() { model.togglePopup() }

    private func checkPointer() {
        guard model.isVisible, let screen = cameraScreen else { return }
        let point = NSEvent.mouseLocation
        let isOverNotch = PanelGeometry.isOverNotch(point, hotspot: hotspot(on: screen))
        if waitingForNotchExit {
            if !isOverNotch { waitingForNotchExit = false }
            return
        }
        if !model.isExpanded {
            if model.openOnHover, isOverNotch { reveal() }
            return
        }
        let content = panel.frame
        if content.contains(point) {
            panel.updatePointerCursor(at: panel.convertPoint(fromScreen: point))
        }
        if !isOverNotch, !content.contains(point),
           !model.isPinned,
           !model.isResizing, !isMenuTracking, NSEvent.pressedMouseButtons == 0 {
            collapse()
        }
    }
}

final class HotKeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var localMonitor: Any?
    let action: (UInt32) -> Void

    init(action: @escaping (UInt32) -> Void) { self.action = action }

    func register() -> Bool {
        // App-local events can arrive directly (including accessibility input),
        // bypassing the system hot-key dispatcher. Handle those here as well.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = Int(event.keyCode)
            let handled = MainActor.assumeIsolated {
                guard modifiers.contains([.control, .option]), !modifiers.contains(.command) else { return false }
                let id: UInt32? = switch keyCode {
                case kVK_Space: 1
                case kVK_UpArrow: 2
                case kVK_DownArrow: 3
                case kVK_ANSI_P: 4
                default: nil
                }
                guard let id else { return false }
                self?.action(id)
                return true
            }
            return handled ? nil : event
        }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr else { return result }
            MainActor.assumeIsolated {
                Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue().action(identifier.id)
            }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return false }
        var success = true
        for (id, key) in [(1, kVK_Space), (2, kVK_UpArrow), (3, kVK_DownArrow), (4, kVK_ANSI_P)] {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(key), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4C505250, id: UInt32(id)), GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference { refs.append(reference) } else { success = false }
        }
        return success
    }

    func unregister() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
        for reference in refs { UnregisterEventHotKey(reference) }
        refs.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}

@main
struct SmartNotchMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    // An optional separate session keeps development checks away from user data.
    private let model = PromptModel(saveURL: ProcessInfo.processInfo.environment["SMARTNOTCH_SESSION_PATH"].map { URL(filePath: $0) })
    private var editor: NSWindow?
    private var prompter: PanelController?
    private var hotKeys: HotKeys?
    private var voiceFollower: VoiceFollower?
    private var statusItem: NSStatusItem?
    private var statusOptions: PromptPanel?
    private var statusOptionsMonitors: [Any] = []
    private var statusSpaceObserver: NSObjectProtocol?
    private var editorPointerMonitors: [Any] = []
    private var editorMenuObservers: [NSObjectProtocol] = []
    private var editorMenuTracking = false
    private var editorHasBeenEntered = false
    private var updates: AppUpdates { model.updates }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOf: icon)
        }
        buildMenu()
        prompter = PanelController(model: model)
        voiceFollower = VoiceFollower(model: model)
        model.onVoiceStart = { [weak self] in self?.voiceFollower?.start() }
        model.onVoiceStop = { [weak self] in self?.voiceFollower?.stop() }
        model.onEditor = { [weak self] in self?.showEditor() }
        model.onReadingStarted = { [weak self] in self?.editor?.orderOut(nil) }
        hotKeys = HotKeys { [weak self] id in
            guard let self else { return }
            switch id {
            case 1: model.togglePlayback()
            case 2: model.navigate(forward: false)
            case 3: model.navigate(forward: true)
            case 4: prompter?.toggle()
            default: break
            }
        }
        model.shortcutsAvailable = hotKeys?.register() ?? false
        buildStatusItem()
        monitorEditorPointer()
        showEditor()
        updates.start()
    }

    @objc func showEditor() {
        prompter?.dismissForEditing()
        if editor == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "SmartNotch — List & content"
            window.minSize = NSSize(width: 940, height: 720)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = NSAppearance(named: .darkAqua)
            window.isMovableByWindowBackground = true
            window.acceptsMouseMovedEvents = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: EditorView(model: model))
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
            window.center()
            editor = window
        }
        if editor?.isMiniaturized == true { editor?.deminiaturize(nil) }
        editor?.makeKeyAndOrderFront(nil)
        editorHasBeenEntered = editor?.frame.contains(NSEvent.mouseLocation) ?? false
        NSApp.activate(ignoringOtherApps: true)
    }

    private func monitorEditorPointer() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.checkEditorPointer() }
        }) { editorPointerMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.checkEditorPointer() }
            return event
        }) { editorPointerMonitors.append(local) }
        for (name, tracking) in [(NSMenu.didBeginTrackingNotification, true), (NSMenu.didEndTrackingNotification, false)] {
            editorMenuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.editorMenuTracking = tracking }
            })
        }
    }

    private func checkEditorPointer() {
        // Keep an isolated development session open for repeatable UI checks.
        guard ProcessInfo.processInfo.environment["SMARTNOTCH_SESSION_PATH"] == nil else { return }
        guard let editor, editor.isVisible, !editor.isMiniaturized else { return }
        if editor.frame.insetBy(dx: -1, dy: -1).contains(NSEvent.mouseLocation) {
            editorHasBeenEntered = true
        } else if editorHasBeenEntered, !editorMenuTracking,
                  editor.attachedSheet == nil, NSApp.modalWindow == nil,
                  !editor.inLiveResize, !model.isStartingVoice, !model.isSettingsPresented, model.chapterToDelete == nil, model.cardToDelete == nil, model.errorMessage == nil,
                  NSEvent.pressedMouseButtons == 0 {
            editorHasBeenEntered = false
            editor.orderOut(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showEditor(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.pause()
        guard model.save() else {
            let alert = NSAlert()
            alert.messageText = "SmartNotch couldn’t save your changes"
            alert.informativeText = "Export your content or resolve the save error before quitting or installing an update."
            alert.addButton(withTitle: "Keep SmartNotch Open")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { model.pause(); model.save(); hotKeys?.unregister() }
    @objc private func togglePanel() { prompter?.toggle() }
    @objc private func importScript() { showEditor(); model.importScript() }
    @objc private func exportScript() { showEditor(); model.exportScript() }
    @objc private func toggleHover() { model.openOnHover.toggle() }
    @objc private func checkForUpdates() { closeStatusOptions(); updates.check() }
    @objc private func toggleAutomaticUpdates() { updates.automaticallyChecks.toggle() }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func buildMenu() {
        let main = NSMenu()
        let appRoot = NSMenuItem()
        let app = NSMenu()
        app.addItem(withTitle: "About SmartNotch", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(item("Check for Updates…", action: #selector(checkForUpdates)))
        app.addItem(item("Automatically Check for Updates", action: #selector(toggleAutomaticUpdates)))
        app.addItem(.separator())
        app.addItem(withTitle: "Hide SmartNotch", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit SmartNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appRoot.submenu = app
        main.addItem(appRoot)
        let fileRoot = NSMenuItem()
        let file = NSMenu(title: "File")
        file.addItem(item("Import Script…", action: #selector(importScript), key: "o"))
        file.addItem(item("Export Script…", action: #selector(exportScript), key: "s"))
        file.addItem(.separator())
        file.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileRoot.submenu = file
        main.addItem(fileRoot)
        let editRoot = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        editRoot.submenu = edit
        main.addItem(editRoot)
        let windowRoot = NSMenuItem()
        let window = NSMenu(title: "Window")
        window.addItem(item("List & Content", action: #selector(showEditor), key: "1"))
        window.addItem(item("Show / Hide Prompter", action: #selector(togglePanel)))
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowRoot.submenu = window
        main.addItem(windowRoot)
        NSApp.windowsMenu = window
        let promptRoot = NSMenuItem()
        let promptMenu = makePrompterMenu()
        promptMenu.title = "Prompter"
        promptRoot.submenu = promptMenu
        main.addItem(promptRoot)
        NSApp.mainMenu = main
    }

    private func buildStatusItem() {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let logo = SmartNotchLogo.image?.copy() as? NSImage {
            logo.size = NSSize(width: 16, height: 16)
            logo.accessibilityDescription = "SmartNotch"
            status.button?.image = logo
        } else {
            status.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "SmartNotch")
        }
        status.button?.toolTip = "SmartNotch"
        status.button?.target = self
        status.button?.action = #selector(toggleStatusOptions)
        statusItem = status
    }

    @objc private func toggleStatusOptions() {
        if statusOptions?.isVisible == true {
            closeStatusOptions()
            return
        }
        guard let button = statusItem?.button, let window = button.window else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? window.screen else { return }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let anchor = buttonFrame.intersects(screen.frame) ? buttonFrame : CGRect(origin: pointer, size: .zero)
        let options = statusOptions ?? makeStatusOptions()
        let size = options.frame.size
        let x = min(max(screen.frame.minX + 6, anchor.midX - size.width / 2), screen.frame.maxX - size.width - 6)
        let menuBarBottom = screen.frame.maxY - max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
        options.setFrameOrigin(NSPoint(x: x, y: min(menuBarBottom, anchor.minY) - size.height - 4))
        options.orderFrontRegardless()
        options.makeKey()
        button.highlight(true)
        monitorStatusOptions()
    }

    private func makeStatusOptions() -> PromptPanel {
        let panel = PromptPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 186),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "SmartNotch options"
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllApplications, .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.allowsKeyboardInput = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.handleWorkspaceKey = { [weak self] event in
            guard event.keyCode == kVK_Escape else { return false }
            self?.closeStatusOptions()
            return true
        }
        let host = NSHostingView(rootView: StatusOptionsView(model: model, checkForUpdates: { [weak self] in self?.updates.check() }, dismiss: { [weak self] in self?.closeStatusOptions() }))
        host.sizingOptions = []
        panel.contentView = host
        statusOptions = panel
        return panel
    }

    private func monitorStatusOptions() {
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.closeStatusOptions() }
        }) { statusOptionsMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            let windowNumber = event.windowNumber
            MainActor.assumeIsolated {
                if let self, windowNumber != self.statusOptions?.windowNumber,
                   windowNumber != self.statusItem?.button?.window?.windowNumber {
                    self.closeStatusOptions()
                }
            }
            return event
        }) { statusOptionsMonitors.append(local) }
        statusSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeStatusOptions() }
        }
    }

    private func closeStatusOptions() {
        statusOptions?.orderOut(nil)
        statusItem?.button?.highlight(false)
        for monitor in statusOptionsMonitors { NSEvent.removeMonitor(monitor) }
        statusOptionsMonitors.removeAll()
        if let statusSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(statusSpaceObserver)
            self.statusSpaceObserver = nil
        }
    }

    private func makePrompterMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item("Show in notch", action: #selector(togglePanel)))
        menu.addItem(.separator())
        menu.addItem(item("Open on hover", action: #selector(toggleHover)))
        menu.addItem(.separator())
        menu.addItem(item("Open editor", action: #selector(showEditor)))
        menu.addItem(item("Check for Updates…", action: #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SmartNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) { return updates.canCheck }
        if menuItem.action == #selector(toggleAutomaticUpdates) {
            menuItem.state = updates.automaticallyChecks ? .on : .off
            return updates.isAvailable
        }
        return true
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        for item in menu.items {
            if item.action == #selector(togglePanel) {
                item.title = model.isVisible && model.isExpanded ? "Hide panel" : "Show panel"
                item.state = .off
            }
            if item.action == #selector(toggleHover) { item.state = model.openOnHover ? .on : .off }
        }
    }
}

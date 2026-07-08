import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel
    var onApply: (Configuration) -> Void
    @State private var permissionsRefreshTrigger = UUID()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            gesturesTab
                .tabItem { Label("Gestures", systemImage: "hand.draw") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 640)
        .onChange(of: model.configuration) { newValue in
            onApply(newValue)
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Enable MouseGestures", isOn: $model.configuration.enabled)
                Toggle("Show gesture feedback overlay", isOn: $model.configuration.showFeedback)
                if #available(macOS 13.0, *) {
                    Toggle("Launch at login", isOn: $model.configuration.launchAtLogin)
                }
            } header: {
                Text("Behavior")
            }

            Section {
                PermissionsCard(onRefresh: {
                    permissionsRefreshTrigger = UUID()
                })
                .id(permissionsRefreshTrigger)
            } header: {
                Text("Permissions")
            } footer: {
                Text("MouseGestures needs these macOS permissions to capture global input events. Click 'Request Access' to be prompted, or 'Open Settings' to grant manually.")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Activation threshold")
                        Spacer()
                        Text("\(Int(model.configuration.activationThreshold)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $model.configuration.activationThreshold, in: 20...300, step: 5)
                }
            } header: {
                Text("Recognition")
            } footer: {
                Text("How far the mouse must travel with the trigger button held before a gesture is recognized. Affects all gestures.")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Direction update delay")
                        Spacer()
                        Text("\(Int(model.configuration.directionUpdateDelay * 1000)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $model.configuration.directionUpdateDelay, in: 0...0.4, step: 0.01)
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Debounce when switching between directions (first direction is always instant). 0 ms = maximum responsiveness.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var gesturesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gestures")
                    .font(.headline)
                Text("Each gesture combines a trigger (a mouse button, a trackpad gesture, or a keyboard shortcut) with an action. You can have multiple gestures for the same action using different triggers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.configuration.gestures.isEmpty {
                EmptyGesturesView {
                    model.addGesture()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.configuration.gestures) { gesture in
                            GestureRow(
                                gesture: gesture,
                                onEdit: { model.editingGestureId = gesture.id },
                                onDelete: { model.deleteGesture(id: gesture.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            HStack {
                Button {
                    model.addGesture()
                } label: {
                    Label("Add Gesture", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Reset to defaults") {
                    model.resetToDefaults()
                }
                Button("Show config in Finder") {
                    model.revealConfigFile()
                }
            }
        }
        .padding()
        .sheet(item: editingGestureBinding) { gesture in
            GestureEditorSheet(
                gesture: gesture,
                onSave: { updated in
                    model.updateGesture(updated)
                    model.closeEditor()
                },
                onCancel: {
                    model.closeEditor()
                }
            )
        }
    }

    private var editingGestureBinding: Binding<Gesture?> {
        Binding<Gesture?>(
            get: { model.editingGesture() },
            set: { newValue in
                if newValue == nil { model.closeEditor() }
            }
        )
    }

    private var aboutTab: some View {
        VStack(spacing: 18) {
            Spacer()
            LogoView(size: 96)
                .padding(.top, 12)
            VStack(spacing: 4) {
                Text("MouseGestures")
                    .font(.system(size: 26, weight: .bold))
                Text("Mouse and trackpad gestures for your Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Divider()
                .frame(width: 220)
            VStack(spacing: 6) {
                aboutRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                aboutRow(label: "License", value: "MIT")
                aboutRow(label: "Author", value: "freezy")
            }
            if let url = URL(string: "https://github.com/freezy/MouseGestures") {
                Link(destination: url) {
                    Label("View on GitHub", systemImage: "link")
                        .font(.callout)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.callout)
        .frame(width: 200)
    }
}

struct PermissionsCard: View {
    let onRefresh: () -> Void
    @State private var accessibilityGranted: Bool = Permissions.isAccessibilityGranted()
    @State private var inputMonitoringGranted: Bool = Permissions.isInputMonitoringGranted()
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status refreshes automatically every 2 seconds while this window is open.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    refresh()
                    onRefresh()
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            PermissionRow(
                title: "Accessibility",
                description: "Required to capture mouse button + drag events globally.",
                granted: accessibilityGranted,
                requestAction: {
                    _ = Permissions.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                },
                openSettingsAction: {
                    Permissions.openAccessibilitySettings()
                }
            )
            Divider()
            PermissionRow(
                title: "Input Monitoring",
                description: "Required to capture keyboard shortcuts and trackpad gestures globally. Requires app restart after granting.",
                granted: inputMonitoringGranted,
                requestAction: {
                    _ = Permissions.requestInputMonitoring()
                    Permissions.openInputMonitoringSettings()
                },
                openSettingsAction: {
                    Permissions.openInputMonitoringSettings()
                }
            )
        }
        .onAppear {
            refresh()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func refresh() {
        let newAccessibility = Permissions.isAccessibilityGranted()
        let newInput = Permissions.isInputMonitoringGranted()
        if newAccessibility != accessibilityGranted || newInput != inputMonitoringGranted {
            accessibilityGranted = newAccessibility
            inputMonitoringGranted = newInput
            onRefresh()
        }
    }

    private func startTimer() {
        stopTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            refresh()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    let requestAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(granted ? Color.green : Color.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(granted ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundStyle(granted ? .secondary : Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(granted ? Color.secondary.opacity(0.15) : Color.orange.opacity(0.15))
                        )
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted {
                    HStack(spacing: 6) {
                        Button("Request Access") {
                            requestAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        Button("Open Settings") {
                            openSettingsAction()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyGesturesView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.draw")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No gestures yet")
                .font(.headline)
            Text("Add a gesture to bind a mouse button or trackpad swipe to an action.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                onAdd()
            } label: {
                Label("Add your first gesture", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct GestureRow: View {
    let gesture: Gesture
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            triggerBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(gesture.trigger.compactName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Image(systemName: gesture.direction.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(gesture.direction.displayName)
                        .font(.subheadline)
                }
                Text(actionSummary)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .help("Edit gesture")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Delete gesture")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }

    private var triggerBadge: some View {
        Image(systemName: gesture.trigger.symbolName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.accentColor.opacity(0.15)))
            .foregroundStyle(Color.accentColor)
    }

    private var actionSummary: String {
        switch gesture.action {
        case .none: return "No action"
        case .keyCombo(let combo): return combo.displayString
        case .shell(let cmd):
            let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Empty shell command" : trimmed
        case .appleScript(let script):
            let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Empty AppleScript" : trimmed
        }
    }
}

enum ActionType: Hashable {
    case none
    case keyCombo
    case shell
    case appleScript
}

struct GestureEditorSheet: View {
    @State var gesture: Gesture
    @State private var selectedPresetId: String = ""
    let onSave: (Gesture) -> Void
    let onCancel: () -> Void

    private var availablePresets: [SystemGestureTemplate] {
        SystemGestureTemplate.all.filter { (template: SystemGestureTemplate) -> Bool in
            if case .trackpad(let gesture) = template.gesture.trigger {
                return SystemGestureTemplate.PresetKind.allCases.contains { $0 == template.kind } && gestureTriggerMatches(gesture, kind: template.kind)
            }
            return false
        }
    }

    private func gestureTriggerMatches(_ trackpad: TrackpadGesture, kind: SystemGestureTemplate.PresetKind) -> Bool {
        switch (trackpad, kind) {
        case (.threeFingerSwipeUp, .missionControl): return true
        case (.threeFingerSwipeDown, .appExpose): return true
        case (.threeFingerSwipeLeft, .previousFullScreen): return true
        case (.threeFingerSwipeRight, .nextFullScreen): return true
        case (.pinchOut, .showDesktop): return true
        case (.pinchIn, .launchpad): return true
        default: return false
        }
    }

    private var presetKind: SystemGestureTemplate.PresetKind? {
        guard case .trackpad(let trackpad) = gesture.trigger else { return nil }
        switch trackpad {
        case .threeFingerSwipeUp: return .missionControl
        case .threeFingerSwipeDown: return .appExpose
        case .threeFingerSwipeLeft: return .previousFullScreen
        case .threeFingerSwipeRight: return .nextFullScreen
        case .pinchOut: return .showDesktop
        case .pinchIn: return .launchpad
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "hand.draw")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("Edit Gesture")
                    .font(.title2)
                    .bold()
                Spacer()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trigger")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Trigger type", selection: triggerTypeBinding) {
                        Text("Mouse").tag(TriggerKind.mouse)
                        Text("Trackpad").tag(TriggerKind.trackpad)
                        Text("Hotkey").tag(TriggerKind.hotkey)
                        Text("Hold Key").tag(TriggerKind.holdKey)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch triggerKind {
                    case .mouse:
                        ButtonPicker(button: mouseButtonBinding)
                    case .trackpad:
                        TrackpadGesturePicker(trackpad: trackpadBinding)
                    case .hotkey:
                        KeyComboRecorder(combo: hotkeyTriggerBinding)
                    case .holdKey:
                        VStack(alignment: .leading, spacing: 6) {
                            KeyComboRecorder(combo: holdKeyTriggerBinding)
                            Text("Press and hold this key, then drag the mouse in any direction. Release the key to fire the action. Works as a trackpad-gesture alternative.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if triggerKind == .trackpad && !availablePresets.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(Color.accentColor)
                            Text("Quick Preset")
                                .font(.subheadline)
                        }
                        Picker("Preset", selection: $selectedPresetId) {
                            Text("Custom").tag("")
                            ForEach(availablePresets) { template in
                                Text(template.title).tag(template.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: selectedPresetId) { newValue in
                            if let template = availablePresets.first(where: { $0.id == newValue }) {
                                gesture.trigger = template.gesture.trigger
                                gesture.direction = template.gesture.direction
                                gesture.action = template.gesture.action
                            }
                        }
                        if let template = availablePresets.first(where: { $0.id == selectedPresetId }) {
                            Text(template.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Direction")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if showsDirectionPicker {
                        let columns = [GridItem(.adaptive(minimum: 60, maximum: 80), spacing: 6)]
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(Direction.allCases, id: \.self) { dir in
                                DirectionChip(
                                    direction: dir,
                                    isSelected: gesture.direction == dir,
                                    onTap: { gesture.direction = dir }
                                )
                            }
                        }
                    } else {
                        Text("Not applicable for this trigger.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Action")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Action type", selection: actionTypeBinding) {
                        Text("None").tag(ActionType.none)
                        Text("Key Combo").tag(ActionType.keyCombo)
                        Text("Shell").tag(ActionType.shell)
                        Text("AppleScript").tag(ActionType.appleScript)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    actionEditor
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if gesture.action.isDangerous {
                        let alert = NSAlert()
                        alert.messageText = "Save potentially dangerous action?"
                        alert.informativeText = "Shell and AppleScript run with your user privileges when the gesture fires. Make sure you trust this command."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Save")
                        alert.addButton(withTitle: "Cancel")
                        guard alert.runModal() == .alertFirstButtonReturn else { return }
                    }
                    onSave(gesture)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 520, height: 640)
        .onAppear {
            selectedPresetId = presetKind.flatMap { kind in
                SystemGestureTemplate.all.first(where: { $0.kind == kind })?.id
            } ?? ""
        }
    }

    @ViewBuilder
    private var actionEditor: some View {
        switch gesture.action {
        case .none:
            Text("This gesture will do nothing.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .keyCombo:
            KeyComboRecorder(combo: comboBinding)
        case .shell:
            ShellCommandEditor(command: shellBinding)
        case .appleScript:
            AppleScriptEditor(script: appleScriptBinding)
        }
    }

    private var triggerKind: TriggerKind {
        switch gesture.trigger {
        case .mouseButton: return .mouse
        case .trackpad: return .trackpad
        case .keyboardShortcut: return .hotkey
        case .keyMouseGesture: return .holdKey
        }
    }

    private var showsDirectionPicker: Bool {
        switch gesture.trigger {
        case .mouseButton: return true
        case .trackpad(let trackpad): return trackpad.isSwipe
        case .keyboardShortcut: return false
        case .keyMouseGesture: return true
        }
    }

    private var triggerTypeBinding: Binding<TriggerKind> {
        Binding<TriggerKind>(
            get: { triggerKind },
            set: { newKind in
                switch newKind {
                case .mouse:
                    if case .mouseButton = gesture.trigger { return }
                    gesture.trigger = .mouseButton(.right)
                case .trackpad:
                    if case .trackpad = gesture.trigger { return }
                    gesture.trigger = .trackpad(.swipeLeft)
                case .hotkey:
                    if case .keyboardShortcut = gesture.trigger { return }
                    gesture.trigger = .keyboardShortcut(KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift]))
                case .holdKey:
                    if case .keyMouseGesture = gesture.trigger { return }
                    gesture.trigger = .keyMouseGesture(KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift]))
                }
            }
        )
    }

    private var mouseButtonBinding: Binding<TriggerButton> {
        Binding<TriggerButton>(
            get: {
                if case .mouseButton(let btn) = gesture.trigger { return btn }
                return .right
            },
            set: { gesture.trigger = .mouseButton($0) }
        )
    }

    private var trackpadBinding: Binding<TrackpadGesture> {
        Binding<TrackpadGesture>(
            get: {
                if case .trackpad(let tp) = gesture.trigger { return tp }
                return .swipeLeft
            },
            set: { gesture.trigger = .trackpad($0) }
        )
    }

    private var hotkeyTriggerBinding: Binding<KeyCombo> {
        Binding<KeyCombo>(
            get: {
                if case .keyboardShortcut(let combo) = gesture.trigger { return combo }
                return KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift])
            },
            set: { gesture.trigger = .keyboardShortcut($0) }
        )
    }

    private var holdKeyTriggerBinding: Binding<KeyCombo> {
        Binding<KeyCombo>(
            get: {
                if case .keyMouseGesture(let combo) = gesture.trigger { return combo }
                return KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift])
            },
            set: { gesture.trigger = .keyMouseGesture($0) }
        )
    }

    private var actionTypeBinding: Binding<ActionType> {
        Binding<ActionType>(
            get: {
                switch gesture.action {
                case .none: return .none
                case .keyCombo: return .keyCombo
                case .shell: return .shell
                case .appleScript: return .appleScript
                }
            },
            set: { newType in
                switch newType {
                case .none:
                    gesture.action = .none
                case .keyCombo:
                    if case .keyCombo = gesture.action { return }
                    gesture.action = .keyCombo(KeyCombo(keyCode: 0x7C, modifiers: [.command]))
                case .shell:
                    if case .shell = gesture.action { return }
                    gesture.action = .shell("")
                case .appleScript:
                    if case .appleScript = gesture.action { return }
                    gesture.action = .appleScript("")
                }
            }
        )
    }

    private var comboBinding: Binding<KeyCombo> {
        Binding<KeyCombo>(
            get: {
                if case .keyCombo(let combo) = gesture.action { return combo }
                return KeyCombo(keyCode: 0x7C, modifiers: [.command])
            },
            set: { gesture.action = .keyCombo($0) }
        )
    }

    private var shellBinding: Binding<String> {
        Binding<String>(
            get: { if case .shell(let c) = gesture.action { return c } else { return "" } },
            set: { gesture.action = .shell($0) }
        )
    }

    private var appleScriptBinding: Binding<String> {
        Binding<String>(
            get: { if case .appleScript(let s) = gesture.action { return s } else { return "" } },
            set: { gesture.action = .appleScript($0) }
        )
    }
}

struct DirectionChip: View {
    let direction: Direction
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: direction.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                Text(direction.shortLabel)
                    .font(.caption2)
            }
            .frame(width: 64, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

enum TriggerKind: Hashable {
    case mouse
    case trackpad
    case hotkey
    case holdKey
}

struct ButtonPicker: View {
    @Binding var button: TriggerButton
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var didCapture: Bool = false
    @State private var customNumber: Int = 0
    @State private var customName: String = ""

    private var isCustomSelected: Bool { !button.isStandard }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Button", selection: presetBinding) {
                    Section("Standard") {
                        ForEach(TriggerButton.standardButtons, id: \.self) { btn in
                            Text(btn.displayName).tag(btn.buttonNumber)
                        }
                    }
                    if isCustomSelected {
                        Section("Custom") {
                            Text(button.displayName).tag(-1)
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)

                Button(isRecording ? "Stop" : "Detect…") {
                    isRecording.toggle()
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .red : .accentColor)
            }

            if isCustomSelected {
                HStack(spacing: 8) {
                    Text("Button #")
                    TextField("", value: $customNumber, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .onChange(of: customNumber) { _ in updateCustom() }
                    TextField("Name (optional)", text: $customName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customName) { _ in updateCustom() }
                }
            }

            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Press any mouse button…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { syncFromButton() }
        .onChange(of: isRecording) { newValue in
            if newValue { startRecording() } else { stopRecording() }
        }
        .onDisappear { stopRecording() }
    }

    private var presetBinding: Binding<Int> {
        Binding<Int>(
            get: { isCustomSelected ? -1 : button.buttonNumber },
            set: { newValue in
                if newValue >= 0, let preset = TriggerButton.standardButtons.first(where: { $0.buttonNumber == newValue }) {
                    button = preset
                    syncFromButton()
                }
            }
        )
    }

    private func updateCustom() {
        button = TriggerButton(buttonNumber: customNumber, customName: customName.isEmpty ? nil : customName)
    }

    private func syncFromButton() {
        customNumber = button.buttonNumber
        customName = button.customName ?? ""
    }

    private func startRecording() {
        didCapture = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard self.isRecording else { return }
            self.monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
                self.handleCapturedEvent(event)
                return event
            }
        }
    }

    private func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if isRecording {
            DispatchQueue.main.async { isRecording = false }
        }
    }

    private func handleCapturedEvent(_ event: NSEvent) {
        guard !didCapture else { return }
        didCapture = true
        let buttonNumber: Int
        switch event.type {
        case .leftMouseDown: buttonNumber = 0
        case .rightMouseDown: buttonNumber = 1
        default: buttonNumber = Int(event.buttonNumber)
        }
        let captured = TriggerButton(buttonNumber: buttonNumber)
        DispatchQueue.main.async {
            self.button = captured
            self.syncFromButton()
            self.isRecording = false
        }
    }
}

struct TrackpadGesturePicker: View {
    @Binding var trackpad: TrackpadGesture

    private var categorizedGestures: [(String, [TrackpadGesture])] {
        var result: [(String, [TrackpadGesture])] = []
        var currentCategory: String?
        var currentGestures: [TrackpadGesture] = []
        for gesture in TrackpadGesture.allCases {
            if gesture.category != currentCategory {
                if let cat = currentCategory {
                    result.append((cat, currentGestures))
                }
                currentCategory = gesture.category
                currentGestures = [gesture]
            } else {
                currentGestures.append(gesture)
            }
        }
        if let cat = currentCategory {
            result.append((cat, currentGestures))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Gesture", selection: $trackpad) {
                ForEach(categorizedGestures, id: \.0) { category, gestures in
                    Section(category) {
                        ForEach(gestures, id: \.self) { gesture in
                            Label(gesture.displayName, systemImage: gesture.symbolName).tag(gesture)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if let systemDefault = trackpad.systemDefault {
                Text("System default: \(systemDefault)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if trackpad.category == "3-Finger Swipes" {
                Text("Note: 3-finger gestures reach this app only when the matching option in System Settings → Trackpad → More Gestures is set to something other than the system default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension Direction {
    var shortLabel: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .upLeft: return "Up-L"
        case .upRight: return "Up-R"
        case .downLeft: return "Down-L"
        case .downRight: return "Down-R"
        }
    }
}

struct ShellCommandEditor: View {
    @Binding var command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Dangerous: runs with your user privileges via /bin/sh -c. Timeout: 5s. Output is not logged in full.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextEditor(text: $command)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 70, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                )
        }
    }
}

struct AppleScriptEditor: View {
    @Binding var script: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Dangerous: AppleScript runs with your user privileges via osascript. Timeout: 5s.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextEditor(text: $script)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 70, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                )
        }
    }
}

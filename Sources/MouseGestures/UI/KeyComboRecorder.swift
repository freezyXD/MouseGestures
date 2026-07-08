import AppKit
import SwiftUI

struct KeyComboRecorder: View {
    @Binding var combo: KeyCombo
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var advancedExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Shortcut")
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)

                comboBadge

                Spacer()

                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop" : "Record…")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .accentColor)

                Button("Clear") {
                    combo = KeyCombo(keyCode: 0, modifiers: [])
                }
                .disabled(combo.isCleared)
            }

            DisclosureGroup("Pick manually", isExpanded: $advancedExpanded) {
                HStack(spacing: 12) {
                    Picker("Key", selection: $combo.keyCode) {
                        ForEach(KeyCombo.standardKeys, id: \.code) { choice in
                            Text(choice.label).tag(choice.code)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)

                    Spacer()

                    Toggle("⌘", isOn: bindingForModifier(.command))
                    Toggle("⌥", isOn: bindingForModifier(.option))
                    Toggle("⌃", isOn: bindingForModifier(.control))
                    Toggle("⇧", isOn: bindingForModifier(.shift))
                }
                .padding(.top, 4)
            }
            .font(.callout)
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                startRecording()
            } else {
                stopRecording()
            }
        }
        .onDisappear { stopRecording() }
    }

    private var comboBadge: some View {
        Group {
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 1.0 : 0.3)
                    Text("Press any key…")
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
                .onDisappear { pulse = false }
            } else if combo.isCleared {
                Text("Not set")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                    )
            } else {
                Text(combo.displayString)
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
        }
    }

    @State private var pulse = false

    private func toggleRecording() {
        isRecording.toggle()
    }

    private func startRecording() {
        NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleCapturedEvent(event)
            return nil
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
        let captured = KeyCombo.from(event: event)
        if captured.keyCode == 0x35 {
            DispatchQueue.main.async {
                isRecording = false
            }
            return
        }
        DispatchQueue.main.async {
            combo = captured
            isRecording = false
        }
    }

    private func bindingForModifier(_ modifier: KeyCombo.Modifier) -> Binding<Bool> {
        Binding<Bool>(
            get: { combo.modifiers.contains(modifier) },
            set: { isOn in
                var mods = Set(combo.modifiers)
                if isOn {
                    mods.insert(modifier)
                } else {
                    mods.remove(modifier)
                }
                combo = KeyCombo(keyCode: combo.keyCode, modifiers: Array(mods), displayKey: combo.displayKey)
            }
        )
    }
}

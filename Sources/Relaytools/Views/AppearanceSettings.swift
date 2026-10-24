import SwiftUI

struct AppearanceSettings: View {
    @Environment(TrainingStore.self) private var workspace
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("customerVoice") private var customerVoice = true

    var body: some View {
        @Bindable var workspace = workspace
        Form {
            Section("Employee Profile") {
                TextField("Your Name", text: $workspace.employeeName)
                    .onSubmit { workspace.save() }
                    .onChange(of: workspace.employeeName) { workspace.save() }
                Text("A local demo profile, visible in your workspace and leaderboard.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in Text(option.title).tag(option.rawValue) }
                }.pickerStyle(.segmented)
            }
            Section("Pitch it!") {
                Toggle("Read customer replies aloud", isOn: $customerVoice)
                LabeledContent("Customer Intelligence", value: CustomerAI.status)
                Text("Customer AI runs on this Mac with Apple Intelligence. Speech recognition may use Apple's servers. Microphone access is requested only when you press the microphone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 510, height: 430)
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}

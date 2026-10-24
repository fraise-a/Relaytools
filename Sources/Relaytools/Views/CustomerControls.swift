import SwiftUI

struct CustomerControls: View {
    @Bindable var practice: PracticeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "person.crop.rectangle").foregroundStyle(Brand.accent)
                Text("The Customer").font(.system(size: 15, weight: .semibold))
            }
            Text("A different person.\nA different conversation.")
                .font(.system(size: 19, weight: .medium)).tracking(-0.4)
            Text("Keep a little unpredictability, or choose who you'd like to practise with.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            traitPicker("Budget", icon: "sterlingsign.circle", selection: $practice.budget, options: CustomerPersona.budgets)
            traitPicker("Personality", icon: "face.smiling", selection: $practice.personality, options: CustomerPersona.personalities)
            traitPicker("Buying Experience", icon: "bag", selection: $practice.experience, options: CustomerPersona.experiences)
            traitPicker("What Matters Most", icon: "scope", selection: $practice.priority, options: CustomerPersona.priorities)
            Divider()
            Label("Surprise Me", systemImage: "shuffle")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.accent)
            Text("Unpinned traits are randomised for every new customer. Their name is always chosen for you.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 282)
        .background(.regularMaterial)
    }

    private func traitPicker(_ title: String, icon: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                Text("Surprise Me").tag("Surprise me")
                Divider()
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden().frame(maxWidth: .infinity).accessibilityLabel(title)
        }
    }
}

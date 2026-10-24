import SwiftUI

struct SidebarView: View {
    @Environment(TrainingStore.self) private var workspace
    @Environment(PracticeStore.self) private var practice
    @Environment(QuickPicStore.self) private var quickPic

    var body: some View {
        @Bindable var workspace = workspace
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Relaytools").font(.system(size: 18, weight: .semibold)).tracking(-0.4)
                    Text("Better conversations.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 32)

            Text("WORKSPACE").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(.tertiary)
                .padding(.horizontal, 22).padding(.bottom, 10)
            List(selection: $workspace.destination) {
                ForEach(Destination.allCases) { destination in
                    Label(destination.rawValue, systemImage: destination.symbol)
                        .labelStyle(SidebarNavigationLabelStyle())
                        .font(.system(size: 12, weight: destination == .pitch ? .semibold : .regular))
                        .padding(.vertical, 5)
                        .tag(destination)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 195)

            if practice.active {
                Button { workspace.destination = .pitch } label: {
                    Label("Return to Live Practice", systemImage: "waveform")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.accent)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 20)
            }

            if quickPic.phase == .playing {
                Button { workspace.destination = .quickPic } label: {
                    Label("Return to QuickPic! · " + QuickPicFormat.time(quickPic.remaining), systemImage: "bolt.fill")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(QuickPicStyle.accent)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(QuickPicStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 16)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Level \(workspace.level)", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Pitch Builder").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                ProgressView(value: workspace.levelProgress).tint(Brand.accent)
                Text("\(QuickPicFormat.xp(workspace.levelRemainder)) / 1,000 XP to next level")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }.padding(16).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 11))
                .padding(.horizontal, 16).padding(.bottom, 20)

            Divider().padding(.horizontal, 18)
            SettingsLink {
                HStack(spacing: 10) {
                    Avatar(initials: workspace.initials, size: 33)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.employeeName).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        Text("Sales professional · Demo").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 2)
                    Image(systemName: "gearshape").font(.system(size: 11)).foregroundStyle(.tertiary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).padding(18).accessibilityLabel("Employee profile: " + workspace.employeeName)
        }
    }
}

private struct SidebarNavigationLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.system(size: 13, weight: .regular))
                .frame(width: 22, height: 18, alignment: .center)
            configuration.title
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

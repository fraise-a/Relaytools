import SwiftUI

struct DashboardJourneyView: View {
    let openTool: (Destination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Label("YOUR PRACTICE JOURNEY", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Brand.accent)
                Text("Three Ways to Build Better Conversations")
                    .font(.system(size: 25, weight: .semibold))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Practise a conversation, put your skills to the test, or sharpen your judgement. Every completed activity contributes to your shared XP.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 14)], spacing: 14) {
                JourneyCard(
                    number: "01", title: "Pitch it!", skill: "Practise Conversations",
                    detail: "Meet an AI customer, understand their needs and rehearse your pitch in your own words.",
                    outcome: "Live signals and a personalised debrief",
                    symbol: "bubble.left.and.bubble.right.fill", tint: Brand.accent
                ) { openTool(.pitch) }
                JourneyCard(
                    number: "02", title: "A-maze-ing!", skill: "Handle Objections",
                    detail: "Explore a 3D maze and earn your way past three customers with convincing, accurate answers.",
                    outcome: "Product knowledge and persuasion in action",
                    symbol: "cube.transparent.fill", tint: .indigo
                ) { openTool(.maze) }
                JourneyCard(
                    number: "03", title: "QuickPic!", skill: "Sharpen Judgement",
                    detail: "Read customer messages and rate the salesperson's response in a fast two-minute challenge.",
                    outcome: "Instant feedback and a review of your mistakes",
                    symbol: "bolt.fill", tint: .orange
                ) { openTool(.quickPic) }
            }

            Label("Choose any tool. Build real skills. Earn XP across your practice.", systemImage: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct JourneyCard: View {
    let number: String
    let title: String
    let skill: String
    let detail: String
    let outcome: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 42, height: 42)
                        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                    Spacer()
                    Text(number)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 21, weight: .semibold)).tracking(-0.4)
                    Text(skill).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text(outcome)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("Open " + title)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 5)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 264, alignment: .topLeading)
            .foregroundStyle(.primary)
            .background(tint.opacity(isHovered ? 0.085 : 0.035), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(tint.opacity(isHovered ? 0.5 : 0.18), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(JourneyCardButtonStyle())
        .onHover { isHovered = $0 }
        .help("Open " + title + ": " + skill)
        .accessibilityLabel(title + ". " + skill)
        .accessibilityHint(detail)
    }
}

private struct JourneyCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.99)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

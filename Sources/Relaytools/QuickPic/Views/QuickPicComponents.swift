import SwiftUI

enum QuickPicStyle {
    static let accent = Color.indigo
    static func color(_ rating: QuickPicRating) -> Color {
        switch rating { case .requiresImprovement: .orange; case .okay: .blue; case .perfect: .teal }
    }
}

struct QuickPicPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(QuickPicStyle.accent.gradient, in: RoundedRectangle(cornerRadius: 11))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

struct QuickPicConversation: View {
    let scenario: QuickPicScenario
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 16 : 23) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(QuickPicStyle.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Product Facts").font(.system(size: 10, weight: .semibold)).foregroundStyle(QuickPicStyle.accent)
                    Text(scenario.facts).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(QuickPicStyle.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            bubble(scenario.customer, customer: true)
            bubble(scenario.salesperson, customer: false)
        }
        .accessibilityElement(children: .contain)
    }

    private func bubble(_ message: String, customer: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            if !customer { Spacer(minLength: compact ? 20 : 45) }
            if customer { Avatar(initials: "C", size: 28, color: .secondary).accessibilityHidden(true) }
            VStack(alignment: customer ? .leading : .trailing, spacing: 7) {
                Text(customer ? "Customer" : "Salesperson").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Text(message)
                    .font(.system(size: compact ? 13 : 16)).lineSpacing(4)
                    .foregroundStyle(customer ? Color.primary : .white)
                    .padding(.horizontal, 18).padding(.vertical, 15)
                    .background(customer ? Color.primary.opacity(0.065) : QuickPicStyle.accent, in: RoundedRectangle(cornerRadius: 18))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 660, alignment: customer ? .leading : .trailing)
            }
            if !customer { Avatar(initials: "S", size: 28, color: QuickPicStyle.accent).accessibilityHidden(true) }
            if customer { Spacer(minLength: compact ? 20 : 45) }
        }
        .accessibilityElement(children: .combine)
    }
}

struct QuickPicRatingButton: View {
    let rating: QuickPicRating
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                HStack {
                    Image(systemName: rating.symbol).font(.system(size: 18, weight: .medium))
                    Spacer()
                    Text("\(rating.rawValue + 1)").font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(5).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
                }
                Text(rating.title).font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(QuickPicStyle.color(rating))
            .padding(17).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(QuickPicStyle.color(rating).opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(QuickPicStyle.color(rating).opacity(0.3), lineWidth: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).opacity(enabled ? 1 : 0.55)
        .keyboardShortcut(KeyEquivalent(Character(String(rating.rawValue + 1))), modifiers: [])
        .accessibilityLabel(rating.title)
        .accessibilityHint("Press \(rating.rawValue + 1). \(rating.definition)")
    }
}

struct QuickPicStat: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.quaternary, lineWidth: 1) }
    }
}

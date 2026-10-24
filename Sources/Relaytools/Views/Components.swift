import SwiftUI

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(22)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: 1) }
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(Brand.accent)
            Text(title).font(.system(size: 30, weight: .semibold)).tracking(-0.9)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

struct StatusPill: View {
    let text: String
    var color: Color = Brand.accent
    var body: some View {
        Text(text).font(.system(size: 10, weight: .medium))
            .foregroundStyle(color).padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
    }
}

struct Avatar: View {
    let initials: String
    var size: CGFloat = 36
    var color: Color = Brand.accent
    var body: some View {
        Text(initials).font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(color).frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.32))
    }
}

struct SignalBar: View {
    let title: String
    let value: Int
    let symbol: String
    var color: Color { value >= 70 ? Brand.accent : value >= 40 ? .orange : .red }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(value)%").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(color)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary.opacity(0.65))
                    Capsule().fill(color.gradient).frame(width: proxy.size.width * Double(value) / 100)
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value) percent")
        .animation(.easeInOut(duration: 0.4), value: value)
    }
}

struct XPText: View {
    let xp: Int
    var body: some View {
        Text("\(xp >= 0 ? "+" : "")\(xp) XP")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(xp >= 0 ? Brand.accent : .orange)
    }
}

struct SessionRow: View {
    let result: SessionResult
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.outcome == .won ? "checkmark.bubble" : "bubble.left.and.text.bubble.right")
                .foregroundStyle(result.outcome == .won ? Brand.accent : .secondary)
                .frame(width: 34, height: 34)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(result.customer).font(.system(size: 12, weight: .medium))
                Text(result.product).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                XPText(xp: result.xp)
                Text(result.date, style: .date).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 9)
    }
}

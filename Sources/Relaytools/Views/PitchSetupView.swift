import SwiftUI

struct PitchSetupView: View {
    @Environment(TrainingStore.self) private var workspace
    @Environment(PracticeStore.self) private var practice

    var body: some View {
        @Bindable var practice = practice
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    PageHeading(eyebrow: "The conversation lab", title: "Pitch it!", subtitle: "A safe place to practise the conversations that count.")
                    HStack(spacing: 9) {
                        Label("Brief Your Customer", systemImage: "1.circle.fill").foregroundStyle(Brand.accent)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        Text("Have a Conversation").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        Text("Get Better").foregroundStyle(.secondary)
                    }.font(.system(size: 10, weight: .medium))

                    Surface {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("What Are You Selling?").font(.system(size: 18, weight: .semibold))
                                    Text("Give the customer enough context to make it real.").font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "text.bubble").font(.system(size: 22)).foregroundStyle(Brand.accent)
                            }
                            samplePrompts
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $practice.brief)
                                    .font(.system(size: 13)).scrollContentBackground(.hidden)
                                    .padding(8).frame(minHeight: 180)
                                    .accessibilityLabel("Product brief")
                                if practice.brief.isEmpty {
                                    Text("Describe your product, pricing, who it's for, and the next step you'd like to agree on…")
                                        .font(.system(size: 13)).foregroundStyle(.tertiary)
                                        .padding(13).allowsHitTesting(false)
                                }
                            }
                            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 9))
                            HStack {
                                Text("Every brief is editable.")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(practice.brief.count) / 4,000").font(.system(size: 10)).foregroundStyle(practice.brief.count > 4000 ? .red : .secondary)
                            }
                            Divider()
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Picker("Customer Engine", selection: $practice.engine) {
                                        ForEach(PracticeEngine.allCases) { Text($0.rawValue).tag($0) }
                                    }.frame(maxWidth: 250).disabled(practice.isBusy)
                                    Text(practice.engine == .onDevice ? CustomerAI.status : "Scripted offline rehearsal, not generative AI")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task { await practice.start(workspace: workspace) }
                                } label: {
                                    HStack(spacing: 8) {
                                        if practice.isBusy { ProgressView().controlSize(.small) }
                                        Text(practice.isBusy ? "Meeting your customer…" : "Meet Your Customer")
                                        if !practice.isBusy { Image(systemName: "arrow.right") }
                                    }.font(.system(size: 12, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                                .disabled(practice.brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || practice.brief.count > 4000 || practice.isBusy)
                            }
                            Text("Briefs are saved to Recents after a session starts. AI conversations run on this Mac.")
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                    }
                    if let error = practice.error {
                        Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled)
                    }
                    recentPrompts
                }
                .padding(30)
            }
            Divider()
            CustomerControls(practice: practice).disabled(practice.isBusy)
        }
    }

    private var samplePrompts: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Start with a Sample").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("Fictional Products").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(SampleBriefs.all) { sample in
                    let selected = practice.brief == sample.text
                    Button {
                        practice.brief = sample.text
                        practice.error = nil
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: sample.symbol)
                                .font(.system(size: 15))
                                .foregroundStyle(Brand.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sample.title).font(.system(size: 11, weight: .semibold))
                                Text(sample.summary).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 2)
                            Image(systemName: selected ? "checkmark.circle.fill" : "arrow.down.left")
                                .font(.system(size: 11))
                                .foregroundStyle(selected ? Brand.accent : .secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .background(selected ? Brand.accent.opacity(0.09) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(selected ? Brand.accent.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(practice.isBusy)
                    .accessibilityLabel("Use sample brief: " + sample.title)
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .help(sample.summary)
                }
            }
        }
    }

    private var recentPrompts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Used Briefs").font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "clock").foregroundStyle(.tertiary)
            }
            if workspace.prompts.isEmpty {
                Text("Your first brief will appear here once you start practising.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 15)
            } else {
                ForEach(workspace.prompts.prefix(5)) { prompt in
                    Button {
                        practice.brief = prompt.text
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: "doc.text").foregroundStyle(Brand.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(prompt.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                Text(prompt.lastUsed, style: .relative).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.left").foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 1) }
                    }.buttonStyle(.plain).disabled(practice.isBusy)
                }
            }
        }
    }
}

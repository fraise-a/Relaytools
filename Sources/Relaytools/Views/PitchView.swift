import SwiftUI

struct PitchView: View {
    @Environment(PracticeStore.self) private var practice
    var body: some View {
        if let result = practice.result {
            ResultsView(result: result, allowsNewPractice: true)
        } else if practice.customer != nil {
            ConversationView()
        } else {
            PitchSetupView()
        }
    }
}

struct ConversationView: View {
    @Environment(TrainingStore.self) private var workspace
    @Environment(PracticeStore.self) private var practice
    @AppStorage("customerVoice") private var customerVoice = true
    @State private var confirmFinish = false
    @State private var voiceDraftPrefix = ""

    var body: some View {
        @Bindable var practice = practice
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                conversationHeader
                Divider()
                transcript
                Divider()
                composer
            }
            Divider()
            customerInspector
        }
        .onChange(of: practice.voice.transcript) {
            practice.draft = [voiceDraftPrefix, practice.voice.transcript].filter { !$0.isEmpty }.joined(separator: " ")
        }
        .onChange(of: customerVoice) { if !customerVoice { practice.voice.stopSpeaking() } }
        .onDisappear {
            practice.voice.stopListening()
            practice.voice.stopSpeaking()
        }
        .confirmationDialog("Finish this practice?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish & See Results") { Task { await practice.finish(workspace: workspace) } }
            Button("Keep Practising", role: .cancel) {}
        } message: { Text("You'll receive a performance summary and XP based on this conversation.") }
    }

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            Avatar(initials: practice.customer?.initials ?? "", size: 40)
            VStack(alignment: .leading, spacing: 5) {
                Text(practice.customer?.name ?? "Customer").font(.system(size: 15, weight: .semibold))
                Text("Customer roleplay · \(practice.activeEngine.rawValue)").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(isOn: $customerVoice) { Image(systemName: customerVoice ? "speaker.wave.2" : "speaker.slash") }
                .toggleStyle(.button).help("Read customer replies aloud").accessibilityLabel("Customer voice")
            Button("Finish Session") { confirmFinish = true }
                .controlSize(.large).disabled(practice.isBusy)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        Label("A practice conversation. A real chance to improve.", systemImage: "sparkles")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                        Spacer()
                    }.padding(.vertical, 12)
                    ForEach(practice.messages) { message in
                        MessageBubble(message: message, customerName: practice.customer?.name ?? "Customer", employeeName: workspace.firstName)
                    }
                    if practice.isBusy {
                        Label(practice.isFinishing ? "Preparing your debrief…" : "\(practice.customer?.name.components(separatedBy: " ").first ?? "Customer") is thinking…", systemImage: "ellipsis.bubble")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.leading, 12)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(24)
            }
            .onChange(of: practice.messages.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: practice.isBusy) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var composer: some View {
        @Bindable var practice = practice
        return VStack(alignment: .leading, spacing: 10) {
            if let error = practice.error {
                HStack(alignment: .top) {
                    Text(error).font(.system(size: 11)).foregroundStyle(.orange).textSelection(.enabled)
                    Spacer()
                    if practice.needsRetry {
                        Button("Edit Reply") { practice.editPendingReply() }.disabled(practice.isBusy)
                        Button("Retry Reply") { Task { await practice.retry(workspace: workspace) } }
                            .disabled(practice.isBusy)
                    }
                }
            }
            if let error = practice.voice.error {
                Text(error).font(.system(size: 11)).foregroundStyle(.orange)
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask a question, listen, then make your pitch…", text: $practice.draft, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .padding(13)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Your reply")
                    .disabled(practice.isBusy || practice.needsRetry || practice.voice.isListening || practice.voice.isPreparing)
                Button {
                    if practice.voice.isListening || practice.voice.isPreparing { practice.voice.stopListening() }
                    else {
                        voiceDraftPrefix = practice.draft
                        Task { await practice.voice.startListening() }
                    }
                } label: {
                    Image(systemName: practice.voice.isListening || practice.voice.isPreparing ? "stop.circle.fill" : "mic")
                        .font(.system(size: 17))
                        .foregroundStyle(practice.voice.isListening || practice.voice.isPreparing ? .red : Brand.accent)
                        .frame(width: 36, height: 39)
                }
                .buttonStyle(.bordered)
                .help(practice.voice.isPreparing ? "Cancel microphone setup" : practice.voice.isListening ? "Stop recording" : "Dictate your reply")
                .accessibilityLabel(practice.voice.isPreparing ? "Cancel microphone setup" : practice.voice.isListening ? "Stop recording" : "Dictate your reply")
                .disabled(practice.isBusy || practice.needsRetry)
                Button {
                    Task { await practice.send(workspace: workspace) }
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .semibold)).frame(width: 27, height: 39)
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Send reply")
                .disabled(practice.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || practice.draft.count > 2500 || practice.isBusy || practice.needsRetry)
            }
            HStack {
                Label(practice.voice.isPreparing ? "Waiting for microphone access…" : practice.voice.isListening ? "Listening. Stop to review before sending." : "Type or use the microphone. ⌘ Return to send.", systemImage: practice.voice.isListening ? "waveform" : "keyboard")
                Spacer()
                Text("\(practice.draft.count) / 2,500")
            }
            .font(.system(size: 9)).foregroundStyle(practice.draft.count > 2500 ? .red : .secondary)
        }.padding(20)
    }

    private var customerInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Text("READ THE ROOM").font(.system(size: 10, weight: .semibold)).tracking(1.4)
                    Spacer()
                    Circle().fill(Brand.accent).frame(width: 6, height: 6)
                    Text("Live").font(.system(size: 10))
                }.foregroundStyle(.secondary)
                Text("Every conversation\nhas signals.")
                    .font(.system(size: 21, weight: .medium)).tracking(-0.5)
                SignalBar(title: "Convinced", value: practice.signals.conviction, symbol: "lightbulb")
                SignalBar(title: "At Ease", value: practice.signals.comfort, symbol: "heart")
                SignalBar(title: "Ready to Purchase", value: practice.signals.readiness, symbol: "bag")
                Text("Practice estimates based on the dialogue, not measurements of a real person.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                Divider()
                Text("CUSTOMER SNAPSHOT").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.tertiary)
                if let customer = practice.customer {
                    snapshot("Budget", value: customer.budget)
                    snapshot("Personality", value: customer.personality)
                    snapshot("Experience", value: customer.experience)
                    snapshot("Priority", value: customer.priority)
                }
                Divider()
                Label("Listen before you pitch.", systemImage: "ear").font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.accent)
                Text("Get curious about the problem. A good next step should feel right for both of you.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .frame(width: 282).background(.regularMaterial)
    }

    private func snapshot(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 12, weight: .medium))
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let customerName: String
    let employeeName: String
    var body: some View {
        HStack(alignment: .top) {
            if !message.isCustomer { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 7) {
                Text(message.isCustomer ? customerName : employeeName + " · You")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(message.isCustomer ? Brand.accent : .secondary)
                Text(message.text)
                    .font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                    .padding(16)
                    .background(message.isCustomer ? Color.primary.opacity(0.045) : Brand.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            }
            .frame(maxWidth: 580, alignment: .leading)
            if message.isCustomer { Spacer(minLength: 60) }
        }
    }
}

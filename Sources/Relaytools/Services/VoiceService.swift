import Foundation
import Observation
@preconcurrency import AVFoundation
@preconcurrency import Speech

@MainActor @Observable
final class VoiceService {
    private(set) var isListening = false
    private(set) var isPreparing = false
    var transcript = ""
    var error: String?
    @ObservationIgnored private let speaker = AVSpeechSynthesizer()
    @ObservationIgnored var muted = false
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognition: SFSpeechRecognitionTask?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let speechPermission: @MainActor () async -> Bool
    @ObservationIgnored private let microphonePermission: @MainActor () async -> Bool

    init(
        speechPermission: @escaping @MainActor () async -> Bool = {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        },
        microphonePermission: @escaping @MainActor () async -> Bool = {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
    ) {
        self.speechPermission = speechPermission
        self.microphonePermission = microphonePermission
    }

    func speak(_ text: String) {
        guard !muted, UserDefaults.standard.object(forKey: "customerVoice") as? Bool ?? true else { return }
        guard !isListening else { return }
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.47
        speaker.speak(utterance)
    }

    func stopSpeaking() { speaker.stopSpeaking(at: .immediate) }

    func startListening() async {
        guard !isListening, !isPreparing else { return }
        isPreparing = true
        error = nil
        stopSpeaking()
        let token = UUID()
        generation = token
        defer { if generation == token { isPreparing = false } }
        let permission = await speechPermission()
        guard generation == token else { return }
        guard permission else { error = "Allow speech recognition in System Settings → Privacy & Security to use the microphone."; return }
        let microphone = await microphonePermission()
        guard generation == token else { return }
        guard microphone else { error = "Allow microphone access in System Settings → Privacy & Security, or type your pitch."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")), recognizer.isAvailable else {
            error = "Speech recognition is not available right now. You can still type your pitch."; return
        }
        let audio = AVAudioEngine()
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { error = "No working microphone was found."; return }
        let bufferRequest = SFSpeechAudioBufferRecognitionRequest()
        bufferRequest.shouldReportPartialResults = true
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            bufferRequest.append(buffer)
        }
        engine = audio
        request = bufferRequest
        transcript = ""
        isListening = true
        recognition = recognizer.recognitionTask(with: bufferRequest) { @Sendable [weak self] result, failure in
            let text = result?.bestTranscription.formattedString
            let finished = result?.isFinal ?? false
            let failed = failure != nil
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if let text { self.transcript = text }
                if finished || failed {
                    self.stopListening()
                    if failed && self.transcript.isEmpty { self.error = "Could not hear your pitch. Try again or type your reply." }
                }
            }
        }
        do {
            audio.prepare()
            try audio.start()
        } catch {
            stopListening()
            self.error = "Could not start the microphone. " + error.localizedDescription
        }
    }

    func stopListening() {
        generation = UUID()
        isPreparing = false
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognition?.cancel()
        engine = nil
        request = nil
        recognition = nil
        isListening = false
    }
}

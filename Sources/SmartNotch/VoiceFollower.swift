import AVFoundation
import Speech

/// Speech and microphone permissions are requested only in response to Start.
/// Offline support is required; this class never falls back to a server request.
final class VoiceFollower {
    private let model: PromptModel
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var startTask: Task<Void, Never>?
    private var sessionID = UUID()

    init(model: PromptModel) { self.model = model }

    func start() {
        stop()
        let id = sessionID
        startTask = Task { [weak self] in
            guard let self else { return }
            let authorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
            guard sessionID == id, !Task.isCancelled else { return }
            guard authorized else { fail("Allow Speech Recognition for SmartNotch in System Settings → Privacy & Security to use Voice mode."); return }
            let microphone = await AVCaptureDevice.requestAccess(for: .audio)
            guard sessionID == id, !Task.isCancelled else { return }
            guard microphone else { fail("Allow Microphone access for SmartNotch in System Settings → Privacy & Security to use Voice mode."); return }
            beginRecognition(id: id)
        }
    }

    private func beginRecognition(id: UUID) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: model.voiceLocale)),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            fail("Offline speech recognition isn’t available for this language on your Mac. Try another Voice language, or use Auto-scroll. Audio has not been sent to a server.")
            return
        }
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = Array(model.script.words.dropFirst(model.wordIndex).prefix(80).map(\.text))
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail("No microphone input is available. Connect a microphone and try again.")
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        self.engine = engine
        self.request = request
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, sessionID == id else { return }
                if let transcript { model.followVoice(transcript) }
                guard sessionID == id else { return }
                if let message { fail("Voice tracking stopped: \(message). Press Start to try again.") }
                else if isFinal, model.isPlaying {
                    // Recognizers may end an utterance after silence. Resume a new
                    // offline request without asking for permissions again.
                    stop()
                    model.pause()
                    model.togglePlayback()
                }
            }
        }
        do {
            engine.prepare()
            try engine.start()
            model.voiceDidStart()
        } catch { fail("The microphone could not start: \(error.localizedDescription)") }
    }

    func stop() {
        sessionID = UUID()
        startTask?.cancel()
        startTask = nil
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        request?.endAudio()
        request = nil
        recognition?.cancel()
        recognition = nil
    }

    private func fail(_ message: String) {
        stop()
        model.pause()
        model.errorMessage = message
        model.onEditor?()
    }
}

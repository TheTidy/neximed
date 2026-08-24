// Neximed — VoiceDictationManager.swift
// Gestor de reconocimiento de voz 100% on-device con SFSpeechRecognizer y AVAudioEngine

import Foundation
import Speech
import AVFoundation
import Accelerate
import Observation

@MainActor
@Observable
final class VoiceDictationManager {

    static let shared = VoiceDictationManager()

    /// Suscripción al cambio de idioma (para recrear el reconocedor de voz)
    private var languageObserver: NSObjectProtocol?

    var isRecording = false
    var isProcessing = false
    var rawTranscript = ""
    var audioLevel: Float = 0.0 // Para animación de ondas en la UI
    var errorMessage: String?

    /// Último nivel enviado a la UI (para throttling desde el hilo de audio).
    /// No es observable: solo lo lee/escribe el callback de audio.
    /// nonisolated(unsafe): accedida desde el hilo de audio en tiempo real
    /// (patrón de Apple para SFSpeechAudioBufferRecognitionRequest — SpeakToMe).
    nonisolated(unsafe) private var lastAudioLevel: Float = 0.0

    private var audioEngine = AVAudioEngine()

    /// Reconocedor creado según el idioma activo de la app (LanguageManager).
    /// Es mutable: se recrea al cambiar el idioma (notificación neximedLanguageChanged).
    nonisolated private var speechRecognizer = Self.makeRecognizer()

    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Crea el reconocedor con el locale de la app; si ese idioma no está
    /// descargado, usa el primer idioma soportado por el dispositivo.
    nonisolated private static func makeRecognizer() -> SFSpeechRecognizer? {
        let appLocale = LanguageManager.shared.currentLanguage.locale
        if let recognizer = SFSpeechRecognizer(locale: appLocale), recognizer.isAvailable {
            return recognizer
        }
        // Fallback: primer locale soportado por el dispositivo
        return SFSpeechRecognizer.supportedLocales()
            .sorted { $0.identifier < $1.identifier }
            .first
            .flatMap { SFSpeechRecognizer(locale: $0) }
    }

    // MARK: - Inicialización

    init() {
        languageObserver = NotificationCenter.default.addObserver(
            forName: .neximedLanguageChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recreateRecognizer()
            }
        }
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    /// Recrea el reconocedor al cambiar el idioma de la app
    private func recreateRecognizer() {
        speechRecognizer = Self.makeRecognizer()
        errorMessage = nil
    }

    // MARK: - Permisos

    func requestPermissions() async -> Bool {
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micAuth = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return speechAuth && micAuth
    }

    // MARK: - Iniciar Grabación y Transcripción en Tiempo Real

    func startRecording() throws {
        // Limpieza forzada de cualquier tarea previa (aunque isRecording sea false)
        forceCleanup()

        // Validar que el reconocedor existe y está disponible en este dispositivo
        // (puede ser nil en simulador o si el idioma es-ES no está descargado)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceError.recognizerUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.cannotCreateRequest
        }

        // Forzar reconocimiento 100% local (sin conexión)
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Monitoreo de ondas de audio y buffer de voz
        // IMPORTANTE: este closure corre en el hilo de audio en tiempo real.
        // Debe ser O(1) y sin asignaciones: usar vDSP y evitar Task por buffer.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)

            // RMS con Accelerate (O(n) vectorizado, sin allocation)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            var rms: Float = 0.0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(buffer.frameLength))
            let level = min(max(rms * 10, 0.05), 1.0)

            // Throttling: solo saltar al main actor si el nivel cambió de forma perceptible
            guard abs(level - (self?.lastAudioLevel ?? 0)) > 0.02 else { return }
            self?.lastAudioLevel = level
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result = result {
                    self?.rawTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self?.stopRecording()
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        rawTranscript = ""
        errorMessage = nil
    }

    // MARK: - Detener Grabación

    func stopRecording() {
        // Guard: evitar doble detención (el callback del recognizer también la invoca)
        guard isRecording else { return }

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        // endAudio + finish: permite que el motor entregue el resultado FINAL
        // (cancel() descartaría las últimas palabras transcritas)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        forceCleanup()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Limpieza incondicional de recursos (sin guard). Interna a la clase.
    private func forceCleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        audioLevel = 0.0
        lastAudioLevel = 0.0
    }

    enum VoiceError: LocalizedError {
        case cannotCreateRequest
        case unauthorized
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .cannotCreateRequest: return "No se pudo iniciar la solicitud de audio."
            case .unauthorized: return "Falta permiso de micrófono o reconocimiento de voz."
            case .recognizerUnavailable: return "Reconocimiento de voz no disponible."
            }
        }
    }
}

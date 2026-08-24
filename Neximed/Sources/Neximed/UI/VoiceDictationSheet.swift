// Neximed — VoiceDictationSheet.swift
// Modal interactivo de dictado por voz con refinamiento y estructuración automática por IA

import SwiftUI
import SwiftData

struct VoiceDictationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var voiceManager = VoiceDictationManager.shared
    @State private var agent = HealthAgent.shared

    var category: HealthAgent.DictationCategory = .symptom
    var onSaved: ((String) -> Void)? = nil

    @State private var hasStarted = false
    @State private var isRefining = false
    @State private var refinedResult: HealthAgent.RefinedDictationResult?
    @State private var editedPolishedText = ""

    var body: some View {
        ZStack {
            // Fondo con la ilustración ambiental de marca (sutil, por debajo del contenido)
            LinearGradient.msBackgroundGradient.ignoresSafeArea()
            Image("background-voice-modal")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.12)

            VStack(spacing: 24) {

                // Cabecera del modal
                headerView
                    .padding(.top, 16)

                // Aviso de error (reconocimiento no disponible, permisos denegados...)
                if let error = voiceManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.msDanger)
                        Text(error)
                            .font(.msCaption)
                            .foregroundStyle(.msTextSecondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.msDanger.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Estado 1: Grabando Voz con Onda Reactiva
                if voiceManager.isRecording {
                    recordingView
                }
                // Estado 2: IA Refinando el Texto
                else if isRefining {
                    refiningAIView
                }
                // Estado 3: Revisión y Confirmación del Texto Pulido
                else if let result = refinedResult {
                    reviewResultView(result)
                }
                // Estado 0: Inicio / Preparado
                else {
                    readyToRecordView
                }

                Spacer()

                // Botonera de Control Inferior
                bottomControlsView
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            voiceManager.stopRecording()
        }
    }

    // MARK: - Subvistas

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dictado Inteligente")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Text("Habla con naturalidad, la IA pulirá tu redacción")
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.msTextTertiary)
            }
        }
    }

    private var readyToRecordView: some View {
        VStack(spacing: 16) {
            // Ilustración Voice-First de marca
            Image("illustration-voice")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .opacity(0.9)

            Text("Toca el botón inferior para empezar a hablar.\nPuedes describir síntomas, pautas o notas.")
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            // Onda animada según el volumen real del micrófono
            HStack(spacing: 6) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient.msAgentGradient)
                        .frame(width: 4, height: CGFloat(20 + (voiceManager.audioLevel * Float(index % 4 + 1) * 35)))
                        .animation(.easeOut(duration: 0.1), value: voiceManager.audioLevel)
                }
            }
            .frame(height: 80)

            // Texto transcrito en vivo
            Text(voiceManager.rawTranscript.isEmpty ? "Escuchando..." : voiceManager.rawTranscript)
                .font(.msBody)
                .foregroundStyle(.msTextPrimary)
                .multilineTextAlignment(.center)
                .padding(16)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxHeight: 140)
        }
    }

    private var refiningAIView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.msAccent)
            Text("Pulinedo redacción y extrayendo datos con IA...")
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)
        }
    }

    private func reviewResultView(_ result: HealthAgent.RefinedDictationResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(LinearGradient.msAgentGradient)
                Text(result.titleSummary)
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            // Editor del texto pulido
            TextEditor(text: $editedPolishedText)
                .font(.msBody)
                .foregroundStyle(.msTextPrimary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .frame(height: 120)

            // Etiquetas extraídas
            if !result.extractedTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(result.extractedTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.msAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.msAccent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // Pregunta sugerida para el médico
            if let question = result.suggestedFollowUpQuestion {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pregunta sugerida para tu doctor:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.msTextTertiary)
                    Text("• \(question)")
                        .font(.system(size: 11))
                        .foregroundStyle(.msTextSecondary)
                }
                .padding(10)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Botonera Inferior

    private var bottomControlsView: some View {
        HStack(spacing: 16) {
            if voiceManager.isRecording {
                Button(action: stopAndRefine) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Terminar y Pulir con IA")
                    }
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.msCardio)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else if refinedResult != nil {
                Button(action: { refinedResult = nil }) {
                    Text("Grabar de nuevo")
                        .font(.msBody)
                        .foregroundStyle(.msTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }

                Button(action: saveEntry) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Confirmar y Guardar")
                    }
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.msAgentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Button(action: startRecordingFlow) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Pulsar para Hablar")
                    }
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.msAgentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.msAccent.opacity(0.35), radius: 12, y: 4)
                }
            }
        }
    }

    // MARK: - Lógica de Acción

    private func startRecordingFlow() {
        Task {
            let granted = await voiceManager.requestPermissions()
            guard granted else { return }
            do {
                try voiceManager.startRecording()
            } catch {
                // Reconocimiento no disponible (simulador, idioma no descargado): avisar
                voiceManager.errorMessage = error.localizedDescription
            }
        }
    }

    private func stopAndRefine() {
        let raw = voiceManager.rawTranscript
        voiceManager.stopRecording()

        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isRefining = true
        Task {
            let refined = await agent.refineAndStructureDictation(raw, category: category)
            refinedResult = refined
            editedPolishedText = refined.polishedText
            isRefining = false
        }
    }

    private func saveEntry() {
        let finalText = editedPolishedText.isEmpty ? (refinedResult?.polishedText ?? "") : editedPolishedText

        switch category {
        case .symptom:
            let entry = SymptomEntry(
                symptomName: refinedResult?.titleSummary ?? "Síntoma",
                intensity: .mild,
                contextTrigger: refinedResult?.extractedTags.joined(separator: ", "),
                rawDictation: finalText
            )
            modelContext.insert(entry)

        case .doctorNote:
            let visit = DoctorVisitRecord(
                specialty: "Consulta General",
                doctorInstructions: finalText
            )
            modelContext.insert(visit)

        case .medication, .general:
            break
        }

        onSaved?(finalText)
        dismiss()
    }
}

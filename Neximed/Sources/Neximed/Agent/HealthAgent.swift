// Neximed — HealthAgent.swift
// Orquestador del asistente: organización de datos, refinamiento de voz con IA y preparación médica
// Compatible con iOS 17+ mediante degradación elegante cuando Apple Intelligence no está disponible

import Foundation
import SwiftData
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
@Observable
final class HealthAgent {

    static let shared = HealthAgent()

    // MARK: - Estado

    var isThinking = false

    /// true solo si el dispositivo soporta Apple Intelligence y la sesión se creó con éxito.
    /// La UI puede usar este flag para indicar el "Modo Básico" (sin refinamiento IA).
    private(set) var aiAvailable = false

    private let healthKit = HealthKitManager.shared

    #if canImport(FoundationModels)
    // Almacenada como `Any?` porque una propiedad *stored* no puede llevar
    // @available (restricción del lenguaje); se expone como computed property
    // tipada, que sí admite @available, delegando en el respaldo type-erased.
    @ObservationIgnored
    private var _session: Any?

    @available(iOS 26.0, macOS 26.0, *)
    private var session: LanguageModelSession? {
        get { _session as? LanguageModelSession }
        set { _session = newValue }
    }
    #endif

    // MARK: - Tipos de resultado (planos, disponibles en todas las versiones)

    struct RefinedDictationResult: Codable, Sendable {
        var polishedText: String
        var titleSummary: String
        var extractedTags: [String]
        var suggestedFollowUpQuestion: String?
    }

    struct AgentResponse: Codable, Sendable {
        var message: String
        var questionsForDoctor: [String]
    }

    struct DoctorVisitSummary: Codable, Sendable {
        var executiveSummary: String
        var keyObservations: [String]
        var questionsToAskDoctor: [String]
    }

    struct FoodAnalysis: Codable, Sendable {
        var description: String
        var estimatedCalories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var confidence: Double   // 0 a 1
    }

    // MARK: - Esquemas @Generable (solo iOS 26+ con FoundationModels)

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct RefinedDictationSchema {
        @Guide(description: "Texto limpio, elegante, claro y sin muletillas, preservando fielmente los datos del paciente.")
        var polishedText: String
        @Guide(description: "Título breve y descriptivo (máx 5 palabras).")
        var titleSummary: String
        @Guide(description: "Etiquetas clave identificadas (síntoma, intensidad, contexto, fármaco).")
        var extractedTags: [String]
        @Guide(description: "Pregunta sugerida para comentar con el médico, si procede.")
        var suggestedFollowUpQuestion: String?
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct AgentResponseSchema {
        @Guide(description: "Respuesta objetiva y descriptiva sin emitir diagnósticos.")
        var message: String
        @Guide(description: "Preguntas sugeridas para consultar con el doctor.")
        var questionsForDoctor: [String]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct DoctorVisitSummarySchema {
        @Guide(description: "Resumen objetivo de 2-3 frases.")
        var executiveSummary: String
        @Guide(description: "Observaciones numéricas clave.")
        var keyObservations: [String]
        @Guide(description: "Preguntas para formular al médico en consulta.")
        var questionsToAskDoctor: [String]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct LabInterpretationSchema {
        @Guide(description: "Explicación clara de los marcadores dentro y fuera de rango, sin emitir diagnósticos.")
        var explanation: String
        @Guide(description: "Lista de marcadores fuera del rango de referencia del laboratorio.")
        var outOfRangeMarkers: [String]
        @Guide(description: "2 preguntas sugeridas para comentar con el médico.")
        var questionsForDoctor: [String]
    }
    #endif

    // MARK: - System Prompt Estricto

    private func buildSystemPrompt(profile: UserProfile?, context: HealthKitManager.HealthContext?) -> String {
        let language = AgentPrompts.Language.current
        var prompt = AgentPrompts.systemPrompt(for: language)

        if let profile {
            let labels = AgentPrompts.profileLabels(for: language)
            prompt += """

            \(labels.name):
            - Nombre: \(profile.name)
            - \(profile.lifestyleSummary)
            - \(labels.allergies) \(profile.allergies.isEmpty ? labels.none : profile.allergies.joined(separator: ", "))
            - Alergias alimentarias: \(profile.foodAllergens.isEmpty ? labels.none : profile.foodAllergens.map(\.rawValue).joined(separator: ", "))
            - \(labels.conditions) \(profile.chronicConditions.isEmpty ? labels.noConditions : profile.chronicConditions.joined(separator: ", "))
            - \(labels.medications) \(profile.currentMedications.isEmpty ? labels.noMedications : profile.currentMedications.joined(separator: ", "))
            """
        }

        if let context {
            prompt += "\n\n\(context.summaryForAgent)"
        }

        return prompt
    }

    // MARK: - Inicializar sesión

    func startSession(profile: UserProfile?) async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let context = try? await healthKit.buildHealthContext(days: 14)
            let systemPrompt = buildSystemPrompt(profile: profile, context: context)

            session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: Instructions(systemPrompt)
            )
            aiAvailable = session != nil
            return
        }
        #endif
        aiAvailable = false
    }

    // MARK: - Categorías de dictado

    enum DictationCategory: String {
        case symptom = "registro de síntomas"
        case doctorNote = "notas de consulta médica"
        case medication = "actualización de medicación"
        case general = "diario general de salud"
    }

    // MARK: - Refinamiento y Mejora de Dictados por Voz (Voice-to-Clean Text)

    func refineAndStructureDictation(
        _ rawTranscription: String,
        category: DictationCategory
    ) async -> RefinedDictationResult {
        let trimmed = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RefinedDictationResult(
                polishedText: rawTranscription,
                titleSummary: "Registro de salud",
                extractedTags: [],
                suggestedFollowUpQuestion: nil
            )
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let session {
            isThinking = true
            defer { isThinking = false }

            let prompt = AgentPrompts.dictationPrompt(
                for: .current,
                category: category.rawValue,
                transcription: trimmed
            )

            do {
                let response = try await session.respond(to: Prompt(prompt), generating: RefinedDictationSchema.self)
                let schema = response.content
                return RefinedDictationResult(
                    polishedText: schema.polishedText,
                    titleSummary: schema.titleSummary,
                    extractedTags: schema.extractedTags,
                    suggestedFollowUpQuestion: schema.suggestedFollowUpQuestion
                )
            } catch {
                // Degradación: limpieza local determinista
                return localRefineDictation(trimmed, category: category)
            }
        }
        #endif

        return localRefineDictation(trimmed, category: category)
    }

    // MARK: - Enviar mensaje general al asistente

    func sendMessage(_ userMessage: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let session {
            isThinking = true
            defer { isThinking = false }

            do {
                let response = try await session.respond(to: Prompt(userMessage), generating: AgentResponseSchema.self)
                return response.content.message
            } catch {
                return await localResponse(for: userMessage)
            }
        }
        #endif
        return await localResponse(for: userMessage)
    }

    // MARK: - Generador de Preparación de Consulta Médica

    func generateDoctorVisitPrep() async -> DoctorVisitSummary {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let session {
            isThinking = true
            defer { isThinking = false }

            let prompt = AgentPrompts.doctorPrepPrompt(for: .current)

            do {
                let response = try await session.respond(to: Prompt(prompt), generating: DoctorVisitSummarySchema.self)
                return DoctorVisitSummary(
                    executiveSummary: response.content.executiveSummary,
                    keyObservations: response.content.keyObservations,
                    questionsToAskDoctor: response.content.questionsToAskDoctor
                )
            } catch {
                return await localDoctorPrep()
            }
        }
        #endif
        return await localDoctorPrep()
    }

    // MARK: - Estructuración de Analíticas de Laboratorio

    func interpretLabResults(_ markers: [LabMarker], patientProfile: UserProfile?) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let session {
            isThinking = true
            defer { isThinking = false }

            let markersText = markers.map { m in
                let statusStr = m.isInRange ? "En rango" : "Fuera de rango (\(m.status.rawValue))"
                return "- \(m.name): \(m.value) \(m.unit) (Ref lab: \(m.referenceMin ?? 0)-\(m.referenceMax ?? 0)) [\(statusStr)]"
            }.joined(separator: "\n")

            let prompt = AgentPrompts.labPrompt(for: .current, markersText: markersText)

            do {
                let response = try await session.respond(to: Prompt(prompt), generating: LabInterpretationSchema.self)
                let schema = response.content
                var text = schema.explanation
                if !schema.outOfRangeMarkers.isEmpty {
                    text += "\n\nMarcadores fuera de rango:\n" + schema.outOfRangeMarkers.map { "• \($0)" }.joined(separator: "\n")
                }
                if !schema.questionsForDoctor.isEmpty {
                    text += "\n\nPreguntas para tu médico:\n" + schema.questionsForDoctor.map { "• \($0)" }.joined(separator: "\n")
                }
                return text
            } catch {
                return localLabInterpretation(markers)
            }
        }
        #endif
        return localLabInterpretation(markers)
    }

    // MARK: - Explicación de diagnóstico (educativa, dado por el médico)

    func explainDiagnosis(_ diagnosis: String) async -> String {
        let trimmed = diagnosis.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Escribe el diagnóstico que te ha dado tu médico para que te lo explique."
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let session {
            isThinking = true
            defer { isThinking = false }

            let prompt = AgentPrompts.diagnosisExplanationPrompt(
                for: .current,
                diagnosis: trimmed
            )

            do {
                let response = try await session.respond(to: Prompt(prompt))
                return response.content
            } catch {
                return localDiagnosisExplanation(trimmed)
            }
        }
        #endif
        return localDiagnosisExplanation(trimmed)
    }

    /// Fallback determinista: explica el término de forma segura y sugiere preguntas
    private func localDiagnosisExplanation(_ diagnosis: String) -> String {
        """
        Has recibido el diagnóstico: \(diagnosis).

        Para entenderlo mejor y hablar con tu médico con claridad, te sugiero preguntarle:
        1. ¿Qué significa exactamente este diagnóstico en mi caso?
        2. ¿Qué seguimiento o pruebas debería hacer a partir de ahora?
        3. ¿Qué síntomas o cambios debería notificarle?

        Recuerda: esta nota es informativa y no sustituye la explicación de tu médico.
        """
    }

    // MARK: - Análisis de foto de comida (macronutrientes estimados)

    func analyzeFoodPhoto(_ imageData: Data) async -> FoodAnalysis {
        // FoundationModels (confirmado en el SDK de iOS 26.5) es un LLM estrictamente
        // de texto: Prompt/LanguageModelSession no aceptan imágenes. No hay forma de
        // enviar `imageData` a la IA on-device de Apple. Este fallback honesto de
        // confianza 0 es el comportamiento definitivo, no un placeholder.
        return FoodAnalysis(
            description: "Análisis visual con IA no disponible en este dispositivo. Registra los macros manualmente.",
            estimatedCalories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            confidence: 0
        )
    }

    // ================================================================
    // MARK: - Modo Básico (fallback determinista, sin Apple Intelligence)
    // ================================================================

    private func localRefineDictation(_ raw: String, category: DictationCategory) -> RefinedDictationResult {
        // 1. Limpiar muletillas comunes del habla coloquial
        var cleaned = raw
        for filler in ["eh", "o sea", "osea", "tipo", "bueno", "pues", "este", "mmm", "ajá", "ya sabes"] {
            cleaned = cleaned.replacingOccurrences(of: filler, with: " ")
        }
        cleaned = cleaned.split(separator: " ").joined(separator: " ")

        // 2. Capitalizar y puntuar
        if let first = cleaned.first {
            cleaned = String(first).uppercased() + cleaned.dropFirst()
        }
        if !cleaned.hasSuffix(".") {
            cleaned += "."
        }

        // 3. Título a partir de las primeras palabras significativas
        let words = cleaned
            .replacingOccurrences(of: ".", with: "")
            .split(separator: " ")
            .map(String.init)
        let titleWords = Array(words.prefix(3))
        let title = titleWords.isEmpty ? "Registro de salud" : titleWords.joined(separator: " ").capitalized

        // 4. Etiquetas por diccionario de términos comunes
        let tags = extractLocalTags(from: cleaned)

        // 5. Pregunta sugerida según la categoría
        let question: String?
        switch category {
        case .symptom:
            question = "¿Debo comentar este síntoma con mi médico en la próxima consulta?"
        case .doctorNote:
            question = "¿Confirmo que estas pautas indicadas por mi doctor son las que debo seguir?"
        case .medication:
            question = "¿Es adecuada la dosis y frecuencia de mi medicación actual?"
        case .general:
            question = "¿Hay algo relevante de mis últimas semanas que deba revisar mi médico?"
        }

        return RefinedDictationResult(
            polishedText: cleaned,
            titleSummary: title,
            extractedTags: tags,
            suggestedFollowUpQuestion: question
        )
    }

    private func extractLocalTags(from text: String) -> [String] {
        let lower = text.lowercased()
        var tags: [String] = []

        let symptoms: [(key: String, tag: String)] = [
            ("cefalea", "Cefalea"), ("dolor de cabeza", "Cefalea"),
            ("mareo", "Mareo"), ("nausea", "Náusea"), ("nauseas", "Náusea"),
            ("fatiga", "Fatiga"), ("cansancio", "Fatiga"),
            ("fiebre", "Fiebre"), ("tos", "Tos"),
            ("dolor", "Dolor"), ("insomnio", "Insomnio"),
            ("ansiedad", "Ansiedad"), ("estres", "Estrés")
        ]
        for item in symptoms where lower.contains(item.key) && !tags.contains(item.tag) {
            tags.append(item.tag)
        }

        let intensity: [(key: String, tag: String)] = [
            ("leve", "Intensidad: Leve"), ("poco", "Intensidad: Leve"),
            ("moderado", "Intensidad: Moderada"), ("bastante", "Intensidad: Moderada"),
            ("intenso", "Intensidad: Intensa"), ("mucho", "Intensidad: Intensa")
        ]
        for item in intensity where lower.contains(item.key) && !tags.contains(item.tag) {
            tags.append(item.tag)
        }

        let context: [(key: String, tag: String)] = [
            ("mañana", "Mañana"), ("desayuno", "Postprandial"),
            ("comida", "Postprandial"), ("tarde", "Tarde"),
            ("noche", "Noche"), ("ejercicio", "Post-ejercicio"),
            ("tras comer", "Postprandial"), ("después de comer", "Postprandial")
        ]
        for item in context where lower.contains(item.key) && !tags.contains(item.tag) {
            tags.append(item.tag)
        }

        return Array(tags.prefix(5))
    }

    private func localResponse(for message: String) async -> String {
        let lower = message.lowercased()
        let context = try? await healthKit.buildHealthContext(days: 7)

        if lower.contains("sueño") || lower.contains("dormir") {
            guard let ctx = context, !ctx.sleep.isEmpty else {
                return "Aún no tengo suficientes datos de sueño de Apple Health. Usa tu Apple Watch para registrar el descanso y vuelve a preguntar."
            }
            let avgHours = ctx.sleep.map { Double($0.totalMinutes) / 60.0 }.average
            let avgDeep = ctx.sleep.map { Double($0.deepMinutes) }.average
            return String(format: "Tu sueño medio esta semana es de %.1f h/noche, con unos %.0f min de sueño profundo por noche. Comenta con tu médico si notas cambios importantes en tu descanso.", avgHours, avgDeep)
        }

        if lower.contains("corazón") || lower.contains("frecuencia") || lower.contains("cardíaca") || lower.contains("fc") {
            guard let ctx = context, !ctx.cardio.isEmpty else {
                return "Aún no tengo datos de frecuencia cardíaca de Apple Health. Asegúrate de tener el Apple Watch sincronizado."
            }
            let avgRHR = ctx.cardio.compactMap(\.restingHeartRate).average
            let avgHRV = ctx.cardio.compactMap(\.heartRateVariability).average
            return String(format: "Tu frecuencia cardíaca en reposo promedio es de %.0f bpm y tu variabilidad (HRV) de %.0f ms esta semana. Lleva estas cifras a tu médico si te preocupan.", avgRHR, avgHRV)
        }

        if lower.contains("pasos") || lower.contains("actividad") || lower.contains("ejercicio") {
            guard let ctx = context, !ctx.activity.isEmpty else {
                return "Aún no tengo datos de actividad de Apple Health. Revisa que HealthKit esté activado."
            }
            let avgSteps = ctx.activity.map { Double($0.steps) }.average
            return String(format: "Has promediado %.0f pasos diarios esta semana. Tu objetivo configurado es de %d pasos.", avgSteps, 10000)
        }

        if lower.contains("proteína") || lower.contains("nutrición") || lower.contains("comida") || lower.contains("kcal") {
            guard let ctx = context, !ctx.nutrition.isEmpty else {
                return "Aún no tengo datos de nutrición registrados. Puedes registrar comidas desde la pestaña Nutrición."
            }
            let avgCal = ctx.nutrition.map(\.totalCalories).average
            let avgProt = ctx.nutrition.map(\.protein).average
            return String(format: "Has promediado %.0f kcal y %.0f g de proteína al día esta semana. Revisa el detalle en la pestaña Nutrición.", avgCal, avgProt)
        }

        if lower.contains("resumen") || lower.contains("cómo estoy") || lower.contains("estado") {
            guard let ctx = context else {
                return "Conecta Apple Health para poder resumir tus constantes."
            }
            let sleepH = ctx.sleep.map { Double($0.totalMinutes) / 60.0 }.average
            let rhr = ctx.cardio.compactMap(\.restingHeartRate).average
            let steps = ctx.activity.map { Double($0.steps) }.average
            return String(format: "Resumen de la semana: %.0f pasos/día, FC reposo %.0f bpm, sueño medio %.1f h/noche. Puedes generar tu dossier PDF para la consulta desde el Dashboard.", steps, rhr, sleepH)
        }

        return "Tengo tus datos organizados en Neximed. Puedes preguntarme por tu sueño, frecuencia cardíaca, actividad, nutrición o pedir un resumen general. Recuerda comentar cualquier duda con tu médico."
    }

    private func localDoctorPrep() async -> DoctorVisitSummary {
        let context = try? await healthKit.buildHealthContext(days: 7)

        guard let ctx = context else {
            return DoctorVisitSummary(
                executiveSummary: "Conecta Apple Health para poder preparar tu consulta con datos objetivos.",
                keyObservations: [],
                questionsToAskDoctor: ["¿Cómo valora mi evolución general?"]
            )
        }

        let sleepH = ctx.sleep.map { Double($0.totalMinutes) / 60.0 }.average
        let rhr = ctx.cardio.compactMap(\.restingHeartRate).average
        let hrv = ctx.cardio.compactMap(\.heartRateVariability).average
        let steps = ctx.activity.map { Double($0.steps) }.average

        var observations: [String] = []
        if !ctx.cardio.isEmpty {
            observations.append(String(format: "FC en reposo media: %.0f bpm.", rhr))
            observations.append(String(format: "Variabilidad cardíaca (HRV) media: %.0f ms.", hrv))
        }
        if !ctx.sleep.isEmpty {
            observations.append(String(format: "Sueño medio de %.1f h/noche en los últimos 7 días.", sleepH))
        }
        if !ctx.activity.isEmpty {
            observations.append(String(format: "Media de %.0f pasos diarios.", steps))
        }
        if observations.isEmpty {
            observations = ["Constantes registradas periódicamente en Apple Health."]
        }

        return DoctorVisitSummary(
            executiveSummary: "He recopilado tus constantes de los últimos 7 días. Lleva este resumen a tu consulta para comentarlo con tu médico.",
            keyObservations: observations,
            questionsToAskDoctor: [
                "¿Considera adecuada mi evolución con estos valores?",
                "¿Debo repetir alguna analítica pronto?",
                "¿Hay algún hábito que debería ajustar según mis datos?"
            ]
        )
    }

    private func localLabInterpretation(_ markers: [LabMarker]) -> String {
        guard !markers.isEmpty else {
            return "No se encontraron marcadores reconocibles en la analítica. Prueba a escanear una imagen con mejor resolución."
        }

        let inRange = markers.filter(\.isInRange).count

        var text = "Analítica procesada: \(inRange) de \(markers.count) marcadores dentro del rango de referencia.\n"

        let out = markers.filter { !$0.isInRange }
        if !out.isEmpty {
            text += "\nMarcadores fuera de rango:\n"
            for m in out {
                text += "• \(m.name): \(m.value) \(m.unit) (Ref: \(m.referenceMin ?? 0)-\(m.referenceMax ?? 0))\n"
            }
        }

        text += "\nEstos datos son informativos: coméntalos con tu médico para su valoración clínica."
        return text
    }
}

// MARK: - Extensión para media (modo básico)

private extension [Double] {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

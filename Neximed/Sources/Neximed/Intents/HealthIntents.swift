// Neximed — HealthIntents.swift
// App Intents para integración con Siri y Apple Intelligence (iOS 26)

import AppIntents
import HealthKit
import Foundation

// MARK: - Señales de lanzamiento (App Intents -> App)

/// Claves de UserDefaults que los intents usan para comunicar a la app
/// qué acción debe abrir al arrancar (openAppWhenRun).
enum NeximedLaunchAction {
    /// El intent de dictado pide abrir la hoja de dictado de síntomas al arrancar
    static let dictateSymptomKey = "neximed.launch.dictateSymptom"
    /// El deep-link neximed://dossier pide generar y compartir el dossier al abrir
    static let dossierKey = "neximed.launch.dossier"
}

// MARK: - Intent: Consultar estado de salud

struct QueryHealthStatusIntent: AppIntent {

    static let title: LocalizedStringResource = "Consultar estado de salud"
    static let description = IntentDescription("Pregunta al agente Neximed sobre tu estado de salud")

    static let openAppWhenRun = false

    @Parameter(title: "Pregunta", description: "¿Qué quieres saber sobre tu salud?")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await HealthAgent.shared.sendMessage(question)
        return .result(value: response)
    }
}

// MARK: - Intent: Registrar comida

struct LogMealIntent: AppIntent {

    static let title: LocalizedStringResource = "Registrar comida"
    static let description = IntentDescription("Registra una comida en Neximed y Apple Health")

    @Parameter(title: "Nombre del alimento o comida")
    var mealName: String

    @Parameter(title: "Calorías (aproximadas)", default: 0.0)
    var calories: Double

    @Parameter(title: "Proteínas en gramos", default: 0.0)
    var protein: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let meal = MealEntry(
            id: UUID(),
            timestamp: Date(),
            name: mealName,
            calories: calories,
            protein: protein,
            carbs: 0,
            fat: 0,
            imageData: nil,
            source: .manual
        )
        try? await HealthKitManager.shared.logMeal(meal)
        return .result(dialog: "\(mealName) registrado: \(Int(calories)) kcal, \(Int(protein))g proteína")
    }
}

// MARK: - Intent: Resumen del día

struct DailySummaryIntent: AppIntent {

    static let title: LocalizedStringResource = "Resumen de salud de hoy"
    static let description = IntentDescription("Obtén un resumen de tu salud del día de parte del agente Neximed")

    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary = await HealthAgent.shared.sendMessage(
            "Dame un resumen breve de mi estado de salud hoy. Máximo 3 frases, lo más importante."
        )
        return .result(value: summary)
    }
}

// MARK: - Intent: Analizar sueño

struct SleepAnalysisIntent: AppIntent {

    static let title: LocalizedStringResource = "Analizar sueño"
    static let description = IntentDescription("Analiza la calidad de tu sueño de anoche")

    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let analysis = await HealthAgent.shared.sendMessage(
            "Analiza mi sueño de anoche y la semana pasada. ¿Cómo ha sido? ¿Qué podría mejorar?"
        )
        return .result(value: analysis)
    }
}

// MARK: - Intent: Dictar un síntoma por voz (abre la app y arranca el dictado)

struct LogSymptomIntent: AppIntent {

    static let title: LocalizedStringResource = "Anotar un síntoma"
    static let description = IntentDescription("Abre Neximed para dictar un síntoma con tu voz")

    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Señal para que la app abra el dictado automáticamente al arrancar
        UserDefaults.standard.set(true, forKey: NeximedLaunchAction.dictateSymptomKey)
        return .result(dialog: "Abriendo Neximed para dictar tu síntoma…")
    }
}

// MARK: - Shortcuts App Shortcuts (sugeridos automáticamente por Siri)

struct NeximedShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DailySummaryIntent(),
            phrases: [
                "Resumen de salud en \(.applicationName)",
                "¿Cómo está mi salud hoy con \(.applicationName)?",
                "Estado de salud \(.applicationName)"
            ],
            shortTitle: "Resumen de salud",
            systemImageName: "heart.text.clipboard.fill"
        )

        AppShortcut(
            intent: SleepAnalysisIntent(),
            phrases: [
                "Analiza mi sueño con \(.applicationName)",
                "¿Cómo dormí anoche con \(.applicationName)?",
                "Mi sueño de anoche en \(.applicationName)"
            ],
            shortTitle: "Analizar sueño",
            systemImageName: "moon.stars.fill"
        )

        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "Registrar comida en \(.applicationName)",
                "Añadir alimento en \(.applicationName)"
            ],
            shortTitle: "Registrar comida",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: LogSymptomIntent(),
            phrases: [
                "Anota un síntoma en \(.applicationName)",
                "Dictar un síntoma con \(.applicationName)",
                "Registrar un síntoma en \(.applicationName)"
            ],
            shortTitle: "Anotar síntoma",
            systemImageName: "waveform"
        )
    }
}

// Neximed — LanguageManager.swift
// Gestión del idioma de la app: detecta el idioma del dispositivo,
// expone el locale para el reconocimiento de voz y centraliza los
// textos del agente de IA por idioma.

import Foundation
import Observation

@MainActor
@Observable
final class LanguageManager {

    static let shared = LanguageManager()

    // MARK: - Idiomas soportados

    enum AppLanguage: String, CaseIterable, Identifiable {
        case spanish = "es"
        case english = "en"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .spanish: return "Español"
            case .english: return "English"
            }
        }

        var locale: Locale {
            switch self {
            case .spanish: return Locale(identifier: "es-ES")
            case .english: return Locale(identifier: "en-US")
            }
        }
    }

    // MARK: - Estado

    /// Idioma activo de la app (persistido)
    private(set) var currentLanguage: AppLanguage

    /// true si el idioma se eligió manualmente (vs. detección automática)
    private(set) var isManualOverride = false

    private let defaultsKey = "app.language"

    private init() {
        // 1. Idioma guardado por el usuario (si existe)
        if let saved = UserDefaults.standard.string(forKey: defaultsKey),
           let lang = AppLanguage(rawValue: saved) {
            currentLanguage = lang
            isManualOverride = true
            return
        }

        // 2. Detección automática desde el idioma del dispositivo
        let preferred = Locale.preferredLanguages.first ?? "es"
        if preferred.hasPrefix("es") {
            currentLanguage = .spanish
        } else if preferred.hasPrefix("en") {
            currentLanguage = .english
        } else {
            // Idioma no soportado: español por defecto (el mercado objetivo)
            currentLanguage = .spanish
        }
    }

    // MARK: - Cambio de idioma

    /// Cambia el idioma manualmente y lo persiste
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        isManualOverride = true
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)

        // Notificar para recrear el reconocedor de voz con el nuevo locale
        NotificationCenter.default.post(name: .neximedLanguageChanged, object: nil)
    }

    /// Vuelve a la detección automática
    func resetToAutoDetect() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        isManualOverride = false
        // Re-ejecutar la detección
        let preferred = Locale.preferredLanguages.first ?? "es"
        currentLanguage = preferred.hasPrefix("es") ? .spanish : .english
        NotificationCenter.default.post(name: .neximedLanguageChanged, object: nil)
    }
}

// MARK: - Notificaciones

extension Notification.Name {
    static let neximedLanguageChanged = Notification.Name("neximed.language.changed")
}
// Neximed — ScreenTimeManager.swift
// Integración con la Screen Time API de Apple (FamilyControls + DeviceActivity).
//
// ⚠️ REQUISITO ESPECIAL: esta integración necesita el entitlement
//    "com.apple.developer.family-controls" que Apple otorga caso por caso
//    (solicitud en developer.apple.com). Hasta que se apruebe, la app usa
//    el auto-reporte del usuario (avgScreenTimeHours en UserProfile).
//
// Arquitectura de la Screen Time API (iOS 16+):
//   - FamilyControls: solicita autorización y gestiona permisos
//   - DeviceActivityReportExtension: extensión que renderiza el informe de uso
//   - DeviceActivityMonitor: detecta umbrales de uso (p. ej. >6h de pantalla)

import Foundation
import Observation

#if canImport(FamilyControls)
@preconcurrency import FamilyControls
#endif
#if canImport(DeviceActivity)
import DeviceActivity
#endif

@MainActor
@Observable
final class ScreenTimeManager {

    static let shared = ScreenTimeManager()

    /// true si el usuario concedió acceso a los datos de Screen Time
    private(set) var isAuthorized = false

    /// true si el entitlement family-controls está disponible en el provisioning
    private(set) var apiAvailable = false

    /// Último error (para mostrarlo en la UI)
    var lastError: String?

    #if canImport(FamilyControls)
    private let center = AuthorizationCenter.shared
    #endif

    private init() {
        checkAvailability()
    }

    /// Comprueba si la API está disponible en este provisioning profile
    func checkAvailability() {
        #if canImport(FamilyControls)
        switch center.authorizationStatus {
        case .approved:
            isAuthorized = true
            apiAvailable = true
        case .denied:
            apiAvailable = true
            lastError = "Acceso a Screen Time denegado. Actívalo en Ajustes."
        case .notDetermined:
            // El entitlement está presente (si no, este status ni se alcanza)
            apiAvailable = true
        @unknown default:
            apiAvailable = false
        }
        #else
        // Sin entitlement family-controls: la app usa el auto-reporte del usuario
        apiAvailable = false
        #endif
    }

    /// Solicita autorización para leer los datos de uso del dispositivo
    func requestAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await center.requestAuthorization(for: .individual)
            isAuthorized = center.authorizationStatus == .approved
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    /// Devuelve el contexto de pantalla para el agente, en lenguaje natural.
    /// Usa el auto-reporte del perfil (funciona siempre) o datos reales si hay API.
    func screenTimeSummary(profileAutoReport: Double?) -> String {
        if isAuthorized {
            return "Horas de pantalla: medición automática activa (Screen Time API)."
        }
        if let hours = profileAutoReport {
            return "Horas de pantalla (auto-reporte): ~\(String(format: "%.1f", hours)) h/día."
        }
        return "Horas de pantalla: no declaradas."
    }
}

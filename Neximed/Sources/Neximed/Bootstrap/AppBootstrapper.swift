// Neximed — AppBootstrapper.swift
// Orquestador del arranque: ejecuta los pasos REALES de inicialización
// y reporta el progreso a la barra de carga del splash.
//
// PRINCIPIO: el progreso avanza SOLO cuando cada tarea termina de verdad.
// No hay sleeps artificiales ni estimaciones — la barra es fiel al trabajo real.

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppBootstrapper {

    static let shared = AppBootstrapper()

    // MARK: - Estado

    /// Progreso real de inicialización (0.0 a 1.0)
    private(set) var progress: Double = 0.0

    /// Texto del paso actual (se muestra en la barra de carga)
    private(set) var phaseLabel = "Preparando Neximed..."

    /// true cuando todos los pasos terminaron → se muestra la app
    private(set) var isReady = false

    private let healthKit = HealthKitManager.shared
    private let security = SecurityManager.shared

    private init() {}

    // MARK: - Arranque

    /// Ejecuta los pasos de inicialización en orden, actualizando el progreso.
    /// Los rangos de progreso son proporcionales al trabajo real de cada paso:
    ///   - Biometría: instantáneo (5%)
    ///   - SwiftData: verificación del container (5%)
    ///   - HealthKit autorización: puede tardar si aparece el diálogo (15%)
    ///   - Precarga de datos: el trabajo PESADO real (45%) → reporta por query
    ///   - Agente IA: inicio de sesión on-device (20%)
    ///   - Finalización (10%)
    func run(modelContext: ModelContext?) async {
        guard !isReady else { return }

        // Paso 1: Estado del sistema (instantáneo)
        phaseLabel = "Comprobando dispositivo..."
        security.checkBiometricsAvailability()
        progress = 0.05

        // Paso 2: Verificación real del contenedor SwiftData
        phaseLabel = "Verificando base de datos segura..."
        let profile = try? modelContext?.fetch(FetchDescriptor<UserProfile>()).first
        progress = 0.10

        // Paso 3: HealthKit — autorización real (el diálogo puede tardar)
        phaseLabel = "Conectando con Apple Health..."
        do {
            try await healthKit.requestAuthorization()
        } catch {
            healthKit.lastError = error
        }
        progress = 0.25

        // Paso 4: Precarga de datos — EL TRABAJO PESADO REAL
        // La barra avanza a medida que cada query de HealthKit completa (25% por query)
        phaseLabel = "Cargando tus constantes (actividad, sueño, corazón)..."
        await healthKit.preloadData(days: 14) { [weak self] subProgress in
            // El rango de este paso es 0.25 → 0.70
            self?.progress = 0.25 + (subProgress * 0.45)
            self?.updatePhaseLabelForPreload(subProgress)
        }
        progress = 0.70

        // Paso 5: Agente de IA — sesión on-device (puede tardar en iOS 26)
        phaseLabel = "Preparando tu asistente..."
        await HealthAgent.shared.startSession(profile: profile)
        progress = 0.90

        // Paso 6: Finalización
        phaseLabel = "Listo. Bienvenido a Neximed"
        progress = 1.0
        isReady = true
    }

    /// Actualiza el texto del paso 4 según qué queries han completado
    private func updatePhaseLabelForPreload(_ subProgress: Double) {
        switch subProgress {
        case ..<0.25:
            phaseLabel = "Cargando tu actividad..."
        case ..<0.5:
            phaseLabel = "Cargando tu sueño..."
        case ..<0.75:
            phaseLabel = "Cargando tus constantes cardíacas..."
        default:
            phaseLabel = "Cargando tu nutrición..."
        }
    }
}
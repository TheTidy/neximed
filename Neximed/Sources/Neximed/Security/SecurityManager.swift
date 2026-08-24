// Neximed — SecurityManager.swift
// Gestor de seguridad de acceso: bloqueo biométrico (Face ID / Touch ID / código)
// para proteger los datos de salud cuando el dispositivo cambia de manos.

import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class SecurityManager {

    static let shared = SecurityManager()

    // MARK: - Estado

    /// true = la app está bloqueada y muestra AppLockView
    private(set) var isLocked = false

    /// true = el dispositivo tiene biometría configurada (Face ID / Touch ID)
    private(set) var biometricsAvailable = false

    /// True si el usuario está desbloqueado en esta sesión (no pedir de nuevo)
    private(set) var hasUnlockedOnce = false

    /// Último error de autenticación (para mostrarlo en la UI)
    var lastError: String?

    private let context = LAContext()

    // MARK: - Inicialización

    private init() {
        checkBiometricsAvailability()
    }

    /// Comprueba si el dispositivo tiene biometría activa (sin pedirla aún)
    func checkBiometricsAvailability() {
        var error: NSError?
        biometricsAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        lastError = error?.localizedDescription
    }

    // MARK: - Bloqueo / Desbloqueo

    /// Bloquea la app (al pasar a background o manualmente)
    func lock() {
        guard !isLocked else { return }
        isLocked = true
        hasUnlockedOnce = false
        lastError = nil
    }

    /// Intenta desbloquear con Face ID / Touch ID / código del dispositivo
    func requestUnlock() async -> Bool {
        let localContext = LAContext()
        var error: NSError?

        // deviceOwnerAuthentication incluye biometría Y código del dispositivo
        guard localContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = error?.localizedDescription ?? "Autenticación no disponible"
            // Sin biometría ni código: permitir acceso (dispositivo sin protección).
            // En un iPhone real con passcode esto nunca ocurre.
            isLocked = false
            hasUnlockedOnce = true
            return true
        }

        let reason = "Desbloquea Neximed para ver tus datos de salud"
        do {
            let success = try await localContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                isLocked = false
                hasUnlockedOnce = true
                lastError = nil
            } else {
                lastError = "Autenticación cancelada"
            }
            return success
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}

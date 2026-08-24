// Neximed — AppLockView.swift
// Pantalla de bloqueo: cubre la app cuando está asegurada.
// Requiere Face ID / Touch ID / código del dispositivo para desbloquear.

import SwiftUI

struct AppLockView: View {

    @State private var security = SecurityManager.shared
    @State private var isAttempting = false

    var body: some View {
        ZStack {
            LinearGradient.msBackgroundGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Icono de candado animado
                ZStack {
                    Circle()
                        .fill(LinearGradient.msAgentGradient.opacity(0.2))
                        .frame(width: 110, height: 110)
                    Circle()
                        .stroke(LinearGradient.msAgentGradient, lineWidth: 2)
                        .frame(width: 110, height: 110)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(LinearGradient.msAgentGradient)
                }

                VStack(spacing: 8) {
                    Text("Neximed bloqueado")
                        .font(.msTitle)
                        .foregroundStyle(.msTextPrimary)
                    Text("Tus datos de salud están protegidos")
                        .font(.msBody)
                        .foregroundStyle(.msTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Botón de desbloqueo
                Button(action: attemptUnlock) {
                    HStack(spacing: 10) {
                        if isAttempting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: security.biometricsAvailable ? "faceid" : "lock.open.fill")
                        }
                        Text(security.biometricsAvailable ? "Desbloquear con Face ID / Touch ID" : "Desbloquear")
                    }
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.msAgentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.msAccent.opacity(0.35), radius: 14, y: 5)
                }
                .padding(.horizontal, 32)
                .disabled(isAttempting)

                // Error de autenticación
                if let error = security.lastError {
                    Text(error)
                        .font(.msCaption)
                        .foregroundStyle(.msDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Text("Protegido con Face ID • Tus datos nunca salen del dispositivo")
                    .font(.system(size: 10))
                    .foregroundStyle(.msTextTertiary)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Intento automático la primera vez que aparece
            if !isAttempting && !security.hasUnlockedOnce {
                attemptUnlock()
            }
        }
    }

    private func attemptUnlock() {
        guard !isAttempting else { return }
        isAttempting = true
        Task {
            _ = await security.requestUnlock()
            isAttempting = false
        }
    }
}

#Preview {
    AppLockView()
}

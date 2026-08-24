// Neximed — SplashScreenView.swift
// Pantalla de arranque con barra de progreso REAL: refleja los pasos de
// inicialización (AppBootstrapper) mientras la app carga en memoria.

import SwiftUI

struct SplashScreenView: View {

    @State private var bootstrapper = AppBootstrapper.shared

    var body: some View {
        ZStack {
            // Fondo de marca
            LinearGradient.msBackgroundGradient.ignoresSafeArea()

            // Imagen central del splash
            VStack(spacing: 28) {
                Spacer()

                Image("splash-centerpiece")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.msBorder.opacity(0.4), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 24, y: 10)

                VStack(spacing: 6) {
                    Text("Neximed")
                        .font(.msDisplayMedium)
                        .foregroundStyle(.msTextPrimary)
                    Text("Tu cuaderno clínico personal")
                        .font(.msBody)
                        .foregroundStyle(.msTextSecondary)
                }

                Spacer()

                // Barra de progreso REAL — animación lineal corta que sigue
                // el dato real (0.12s): la barra nunca va "por delante" del trabajo.
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.msSurfaceElevated)
                            Capsule()
                                .fill(LinearGradient.msAgentGradient)
                                .frame(width: geo.size.width * bootstrapper.progress)
                        }
                    }
                    .frame(height: 6)
                    .animation(.linear(duration: 0.12), value: bootstrapper.progress)

                    // Texto del paso actual + porcentaje animado
                    HStack {
                        Text(bootstrapper.phaseLabel)
                            .font(.msCaption)
                            .foregroundStyle(.msTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Text("\(Int(bootstrapper.progress * 100))%")
                            .font(.msCaption)
                            .foregroundStyle(.msAccent)
                            .contentTransition(.numericText())
                            .animation(.linear(duration: 0.12), value: bootstrapper.progress)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SplashScreenView()
}
// Neximed — ContentView.swift
// Navegación principal de la app: solo se monta la pestaña activa (máxima fluidez)

import SwiftUI
import SwiftData

struct ContentView: View {

    @State private var healthKit = HealthKitManager.shared
    @State private var agent = HealthAgent.shared
    @State private var security = SecurityManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .dashboard
    @State private var showOnboarding = false

    @Query private var profiles: [UserProfile]
    var currentProfile: UserProfile? { profiles.first }

    enum AppTab: String, CaseIterable {
        case dashboard   = "Dashboard"
        case agent       = "Asistente"
        case nutrition   = "Nutrición"
        case labs        = "Laboratorio"
        case trends      = "Tendencias"
        case profile     = "Perfil"

        var icon: String {
            switch self {
            case .dashboard:  return "heart.text.clipboard.fill"
            case .agent:      return "brain.head.profile.fill"
            case .nutrition:  return "fork.knife"
            case .labs:       return "testtube.2"
            case .trends:     return "chart.line.uptrend.xyaxis"
            case .profile:    return "person.crop.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .dashboard:  return .msAccent
            case .agent:      return .msSleep
            case .nutrition:  return .msNutrition
            case .labs:       return .msLabs
            case .trends:     return .msActivity
            case .profile:    return .msAccentSecondary
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Fondo global
            LinearGradient.msBackgroundGradient
                .ignoresSafeArea()

            // Contenido de la tab activa SOLO (sin precargar las otras pestañas:
            // evita montar 5 vistas + sus queries de HealthKit en el arranque)
            Group {
                switch selectedTab {
                case .dashboard: DashboardView()
                case .agent:     AgentChatView()
                case .nutrition: NutritionView()
                case .labs:      LabsView()
                case .trends:    TrendsView()
                case .profile:   ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .id(selectedTab)  // reinicia el estado al cambiar de pestaña

            // TabBar personalizada
            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .task {
            // La autorización y precarga de HealthKit ya las hizo AppBootstrapper
            // durante el splash. Aquí solo aseguramos la sesión del agente con
            // el perfil actual (que puede haberse creado en el onboarding).
            await agent.startSession(profile: currentProfile)
        }
        .onAppear {
            if profiles.isEmpty {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        // SEGURIDAD: bloqueo automático al pasar a background
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                // Si alguien cambia de app o apaga la pantalla, Neximed se bloquea
                if security.hasUnlockedOnce {
                    security.lock()
                }
            case .active:
                // Al volver, la AppLockView se muestra y pide biometría
                break
            @unknown default:
                break
            }
        }
        // Pantalla de bloqueo por encima de todo
        .overlay {
            if security.isLocked {
                AppLockView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.msEase, value: security.isLocked)
    }
}

// MARK: - TabBar Personalizada

struct CustomTabBar: View {

    @Binding var selectedTab: ContentView.AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.AppTab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    onTap: {
                        withAnimation(.msSpring) {
                            selectedTab = tab
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.msSurfaceElevated.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.msBorder.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: -4)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

struct TabBarItem: View {
    let tab: ContentView.AppTab
    let isSelected: Bool
    let onTap: () -> Void

    @State private var scale = 1.0

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tab.color.opacity(0.2))
                            .frame(width: 48, height: 36)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? tab.color : Color.msTextTertiary)
                        .scaleEffect(scale)
                        .animation(.msSpring, value: isSelected)
                }
                .frame(width: 48, height: 36)

                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tab.color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onChange(of: isSelected) { _, newVal in
            if newVal {
                scale = 1.2
                withAnimation(.spring(duration: 0.3, bounce: 0.6)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - Onboarding Neximed

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var currentPage = 0

    private let pages: [(image: String, title: String, subtitle: String)] = [
        (
            image: "onboarding-1-voice",
            title: "Habla, Neximed escucha",
            subtitle: "Dicta tus síntomas con voz natural. La IA on-device pule la redacción y extrae los datos clave."
        ),
        (
            image: "onboarding-2-scanner",
            title: "Escanea tus analíticas",
            subtitle: "Fotografía tu analítica de laboratorio y Neximed extrae y organiza más de 25 biomarcadores."
        ),
        (
            image: "onboarding-3-dossier",
            title: "Dossier para tu médico",
            subtitle: "Genera un PDF clínico de 1 página con tus constantes, medicación y preguntas preparadas."
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient.msBackgroundGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 10)

                // Carrusel de páginas con ilustraciones
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 460)

                // Indicadores de página
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.msAccent : Color.msTextTertiary.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .animation(.msEase, value: currentPage)

                // Última página: campo de nombre
                if currentPage == pages.count - 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("¿Cómo te llamas?")
                            .font(.msCaption)
                            .foregroundStyle(.msTextSecondary)
                        TextField("Tu nombre", text: $name)
                            .font(.msBody)
                            .foregroundStyle(.msTextPrimary)
                            .padding(14)
                            .background(Color.msSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.msAccent.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 8)

                // Botón principal
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation(.msSpring) { currentPage += 1 }
                    } else {
                        createProfile()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Continuar" : "Comenzar con Neximed")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient.msAgentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.msAccent.opacity(0.35), radius: 14, y: 5)
                }
                .padding(.horizontal, 32)
                .disabled(currentPage == pages.count - 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("Neximed es una herramienta de organización personal y no sustituye el criterio de un profesional médico.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.msTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func onboardingPage(_ page: (image: String, title: String, subtitle: String)) -> some View {
        VStack(spacing: 18) {
            Image(page.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.msBorder.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, y: 8)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.msTitle)
                    .foregroundStyle(.msTextPrimary)
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.msBody)
                    .foregroundStyle(.msTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
        .padding(.horizontal, 20)
    }

    private func createProfile() {
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespaces))
        modelContext.insert(profile)
        dismiss()
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)
            Spacer()
        }
    }
}

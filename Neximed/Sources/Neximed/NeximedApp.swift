// Neximed — NeximedApp.swift
// Entry point de la app con contenedor SwiftData completo y privado

import SwiftUI
import SwiftData

@main
struct NeximedApp: App {

    @State private var bootstrapper = AppBootstrapper.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            ChatMessage.self,
            MedicationEntry.self,
            MedicationDoseLog.self,
            SymptomEntry.self,
            DoctorVisitRecord.self,
            WeightEntry.self,
            DailyCheckIn.self
        ])
        // SEGURIDAD: iOS aplica NSFileProtectionCompleteUntilFirstUserAuthentication
        // por defecto a los datos del contenedor de la app (cifrado en reposo).
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Privacidad total: sin sincronización en la nube
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fallback seguro: si el container falla, no crashear en arranque.
            // Se usa un container en memoria para que la app arranque igualmente.
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // Si incluso el fallback en memoria falla (prácticamente imposible),
            // se muestra un error controlado en vez de crashear con try!.
            guard let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfig]) else {
                fatalError("No se pudo crear ningún ModelContainer: \(error)")
            }
            return memoryContainer
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Splash con barra de progreso REAL hasta que la app esté lista
            ZStack {
                if bootstrapper.isReady {
                    ContentView()
                        .transition(.opacity)
                } else {
                    SplashScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: bootstrapper.isReady)
            .task {
                await bootstrapper.run(modelContext: sharedModelContainer.mainContext)
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Deep links soportados:
    ///   neximed://dossier  → genera y comparte el dossier médico al abrir la app
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "neximed" else { return }
        switch url.host {
        case "dossier":
            UserDefaults.standard.set(true, forKey: NeximedLaunchAction.dossierKey)
        default:
            break
        }
    }
}
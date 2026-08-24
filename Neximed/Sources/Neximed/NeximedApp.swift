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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none,  // Privacidad total: sin sincronización en la nube
            // SEGURIDAD: los datos solo son accesibles tras el primer desbloqueo
            // del dispositivo (cifrado en reposo gestionado por iOS File Protection)
            protectionType: .completeUntilFirstUserAuthentication
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fallback seguro: si el container falla, no crashear en arranque.
            // Se usa un container en memoria para que la app arranque igualmente.
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memoryConfig])
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
        }
        .modelContainer(sharedModelContainer)
    }
}
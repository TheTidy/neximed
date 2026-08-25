// Neximed — DemoDataSeeder.swift
// Modo Demo (SOLO DEBUG): rellena datos ficticios realistas la primera vez que
// la app arranca en el simulador, para que las demos y las capturas de la App
// Store muestren contenido. Nunca se ejecuta en builds de Release.

import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {

    private static let seededKey = "neximed.demoSeeded"

    /// Siembra la demo una única vez y solo si no existe un perfil real.
    /// Para repetir la siembra: borra la app (o el flag neximed.demoSeeded).
    static func seedIfNeeded(modelContext: ModelContext?) {
        #if DEBUG
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard let context = modelContext else { return }

        // Nunca sobrescribir datos reales del usuario
        let existingProfiles = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard existingProfiles == 0 else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        seedProfile(into: context)
        seedWeights(into: context)
        seedSymptoms(into: context)
        seedCheckIns(into: context)
        seedMedications(into: context)
        seedDoctorVisits(into: context)
        try? context.save()

        seedLabHistory()

        UserDefaults.standard.set(true, forKey: seededKey)
        #endif
    }

    // MARK: - Perfil

    private static func seedProfile(into context: ModelContext) {
        let profile = UserProfile(name: "Ana Demo")
        profile.birthDate = Calendar.current.date(byAdding: .year, value: -32, to: Date())
        profile.biologicalSex = "Mujer"
        profile.heightCm = 168
        profile.weightKg = 63
        profile.bloodType = "A+"
        profile.allergies = ["Penicilina"]
        profile.foodAllergens = [.gluten]
        profile.chronicConditions = ["Asma leve"]
        profile.currentMedications = ["Eutirox 50 mcg"]
        profile.smokingStatus = "Nunca fumador"
        profile.alcoholFrequency = "Ocasional"
        profile.dietType = "Mediterránea"
        profile.dietaryRestrictions = ["Baja en sal"]
        profile.mealsPerDay = 4
        profile.waterIntakeLiters = 2.0
        profile.workSchedule = "Teletrabajo"
        profile.workHoursPerWeek = 40
        profile.sleepSchedule = "Madrugador"
        profile.physicalActivityLevel = "Moderado"
        profile.avgScreenTimeHours = 5.5
        profile.emergencyContactName = "Carlos"
        profile.emergencyContactPhone = "600 123 456"
        context.insert(profile)
    }

    // MARK: - Peso (10 semanas con tendencia)

    private static func seedWeights(into context: ModelContext) {
        let calendar = Calendar.current
        for i in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -7 * i, to: Date()) ?? Date()
            let weight = 65.5 - Double(i) * 0.2
            context.insert(WeightEntry(date: date, weightKg: weight))
        }
    }

    // MARK: - Síntomas recientes

    private static func seedSymptoms(into context: ModelContext) {
        context.insert(SymptomEntry(
            symptomName: "Cefalea",
            intensity: .mild,
            durationMinutes: 45,
            contextTrigger: "Tras horas de pantalla",
            timestamp: Date().addingTimeInterval(-2 * 86400)
        ))
        context.insert(SymptomEntry(
            symptomName: "Fatiga",
            intensity: .moderate,
            durationMinutes: 120,
            contextTrigger: "Semana de trabajo intensa",
            timestamp: Date().addingTimeInterval(-5 * 86400)
        ))
        context.insert(SymptomEntry(
            symptomName: "Mareo",
            intensity: .mild,
            durationMinutes: 10,
            contextTrigger: "En ayunas",
            timestamp: Date().addingTimeInterval(-12 * 86400)
        ))
    }

    // MARK: - Check-ins de bienestar (últimos 5 días)

    private static func seedCheckIns(into context: ModelContext) {
        let moods: [DailyCheckIn.MoodLevel] = [.good, .neutral, .great, .good, .neutral]
        let energies: [DailyCheckIn.EnergyLevel] = [.medium, .medium, .high, .medium, .low]
        let quality = [4, 3, 5, 4, 3]
        for i in 0..<5 {
            context.insert(DailyCheckIn(
                date: Date().addingTimeInterval(-Double(i) * 86400),
                mood: moods[i],
                energyLevel: energies[i],
                sleepQuality: quality[i]
            ))
        }
    }

    // MARK: - Botiquín

    private static func seedMedications(into context: ModelContext) {
        let eutirox = MedicationEntry(
            name: "Eutirox",
            dosage: "50 mcg",
            frequency: "Cada mañana en ayunas",
            type: .prescription,
            startDate: Date().addingTimeInterval(-180 * 86400),
            prescribingDoctor: "Dr. Mora",
            dosePerIntake: "1 comprimido",
            intakeTimes: ["08:00"],
            reminderEnabled: false,
            sideEffects: ["Palpitaciones leves"],
            experiencedSideEffects: []
        )
        let vitaminaD = MedicationEntry(
            name: "Vitamina D3",
            dosage: "2000 UI",
            frequency: "Diaria con la comida",
            type: .supplement,
            startDate: Date().addingTimeInterval(-90 * 86400),
            intakeTimes: ["14:00"],
            reminderEnabled: false
        )
        context.insert(eutirox)
        context.insert(vitaminaD)
    }

    // MARK: - Diario médico (visitas)

    private static func seedDoctorVisits(into context: ModelContext) {
        let general = DoctorVisitRecord(
            specialty: "Medicina General",
            visitDate: Date().addingTimeInterval(-30 * 86400),
            doctorName: "Dra. Ruiz",
            clinicOrHospital: "Centro de Salud Centro",
            reasonsForVisit: ["Revisión anual"],
            doctorInstructions: "Mantener dieta mediterránea y ejercicio moderado. Controlar tensión en 6 meses.",
            nextReviewDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())
        )
        let endocrino = DoctorVisitRecord(
            specialty: "Endocrinología",
            visitDate: Date().addingTimeInterval(-90 * 86400),
            doctorName: "Dr. Mora",
            clinicOrHospital: "Hospital Comarcal",
            reasonsForVisit: ["Control tiroideo"],
            doctorInstructions: "Seguir con Eutirox 50 mcg en ayunas. Repetir analítica en 3 meses.",
            nextReviewDate: nil
        )
        context.insert(general)
        context.insert(endocrino)
    }

    // MARK: - Historial de analíticas (para la comparativa longitudinal)

    private static func seedLabHistory() {
        let store = LabHistoryStore.shared
        store.removeAll()

        func marker(_ name: String, _ value: Double, _ unit: String, _ min: Double, _ max: Double) -> LabMarker {
            LabMarker(
                id: UUID(),
                name: name,
                value: value,
                unit: unit,
                referenceMin: min,
                referenceMax: max,
                status: .normal,
                testDate: nil
            )
        }

        func result(daysAgo: Double, glucose: Double, cholesterol: Double, vitaminD: Double) -> LabResult {
            LabResult(
                id: UUID(),
                date: Date().addingTimeInterval(-daysAgo * 86400),
                laboratoryName: "Lab Central",
                markers: [
                    marker("Glucosa", glucose, "mg/dL", 70, 110),
                    marker("Colesterol total", cholesterol, "mg/dL", 0, 200),
                    marker("Vitamina D", vitaminD, "ng/mL", 20, 50)
                ],
                source: .ocr,
                rawImageData: nil
            )
        }

        store.add(result(daysAgo: 180, glucose: 92, cholesterol: 210, vitaminD: 28))
        store.add(result(daysAgo: 90, glucose: 95, cholesterol: 205, vitaminD: 34))
        store.add(result(daysAgo: 15, glucose: 88, cholesterol: 196, vitaminD: 41))
    }
}

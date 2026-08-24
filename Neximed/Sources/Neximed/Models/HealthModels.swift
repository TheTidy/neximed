// Neximed — HealthModels.swift
// Modelos de datos completos para Neximed (SwiftData + Estructuras de Soporte)

import Foundation
import SwiftData

// MARK: - Perfil del Usuario y Datos de Emergencia (Ficha ICE)

@Model
final class UserProfile {
    var id: UUID
    var name: String

    // MARK: - Datos demográficos
    var birthDate: Date?
    var biologicalSex: String?            // "Hombre", "Mujer", "Otro"
    var heightCm: Double?
    var weightKg: Double?

    // MARK: - Ficha clínica
    var bloodType: String?               // Ej: "A+", "0-", "B+"
    var allergies: [String]              // Ej: ["Penicilina", "AINEs"] — alergias medicamentosas
    var foodAllergens: [Allergen]        // Alergenos alimentarios (los 14 de la UE + intolerancias)
    var chronicConditions: [String]      // Ej: ["Hipotiroidismo", "Sarcoidosis", "Asma"]
    var currentMedications: [String]     // Ej: ["Eutirox 50 mcg", "Vitamina D3"]
    var smokingStatus: String?           // "Nunca fumador", "Exfumador", "Fumador"
    var alcoholFrequency: String?        // "Nunca", "Ocasional", "Semanal", "Diario"

    // MARK: - Nutrición y dieta
    var dietType: String?                // "Omnívora", "Vegetariana", "Vegana", "Mediterránea", "Keto", "Sin gluten"...
    var dietaryRestrictions: [String]    // Ej: ["Sin lactosa", "Sin gluten", "Baja en sodio"]
    var mealsPerDay: Int                 // Comidas habituales al día
    var waterIntakeLiters: Double?       // Consumo de agua diario aprox.

    // MARK: - Trabajo y rutina
    var workSchedule: String?            // "Diurno", "Nocturno", "Turnos rotativos", "Teletrabajo", "Jubilado"
    var workHoursPerWeek: Int?
    var sleepSchedule: String?           // "Madrugador", "Noctámbulo", "Irregular"
    var physicalActivityLevel: String?   // "Sedentario", "Ligero", "Moderado", "Intenso"

    // MARK: - Hábitos digitales (horas de pantalla)
    /// Estimación del usuario (auto-reporte) — funciona siempre
    var avgScreenTimeHours: Double?
    /// Si la integración Screen Time API está aprobada por Apple, se rellena automáticamente
    var screenTimeAutoTracked: Bool = false

    // MARK: - Contacto de emergencia (Ficha ICE)
    var emergencyContactName: String?
    var emergencyContactPhone: String?

    // MARK: - Objetivos personales de descanso y actividad
    var goalCalories: Double
    var goalSteps: Int
    var goalSleepHours: Double
    var goalProtein: Double

    var lastUpdated: Date

    init(name: String = "Usuario") {
        self.id = UUID()
        self.name = name
        self.allergies = []
        self.foodAllergens = []
        self.chronicConditions = []
        self.currentMedications = []
        self.dietaryRestrictions = []
        self.mealsPerDay = 3
        self.goalCalories = 2000
        self.goalSteps = 10000
        self.goalSleepHours = 7.5
        self.goalProtein = 60
        self.lastUpdated = Date()
    }

    // MARK: - Cálculos derivados

    /// Edad en años (para el agente y el dossier)
    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    /// IMC (Índice de Masa Corporal) — informativo, nunca diagnóstico
    var bmi: Double? {
        guard let heightCm, let weightKg, heightCm > 0 else { return nil }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    /// Resumen de estilo de vida para el agente (contexto en lenguaje natural)
    var lifestyleSummary: String {
        var parts: [String] = []

        if let age {
            parts.append("Edad: \(age) años")
        }
        if let sex = biologicalSex {
            parts.append("Sexo: \(sex)")
        }
        if let heightCm, let weightKg {
            parts.append("Altura: \(Int(heightCm)) cm, Peso: \(Int(weightKg)) kg")
        }
        if let bmi {
            parts.append("IMC: \(String(format: "%.1f", bmi))")
        }
        if !chronicConditions.isEmpty {
            parts.append("Patologías previas: \(chronicConditions.joined(separator: ", "))")
        }
        if let diet = dietType {
            parts.append("Dieta: \(diet)")
        }
        if !dietaryRestrictions.isEmpty {
            parts.append("Restricciones: \(dietaryRestrictions.joined(separator: ", "))")
        }
        if let work = workSchedule {
            parts.append("Horario laboral: \(work)")
        }
        if let activity = physicalActivityLevel {
            parts.append("Actividad física: \(activity)")
        }
        if let screen = avgScreenTimeHours {
            parts.append("Horas de pantalla: ~\(String(format: "%.1f", screen)) h/día")
        }
        if let smoking = smokingStatus {
            parts.append("Tabaco: \(smoking)")
        }
        if let alcohol = alcoholFrequency {
            parts.append("Alcohol: \(alcohol)")
        }

        return parts.isEmpty ? "Sin datos de perfil completados." : parts.joined(separator: " | ")
    }
}

// MARK: - Botiquín de Medicación y Suplementos

@Model
final class MedicationEntry {
    var id: UUID
    var name: String                     // Ej: "Eutirox", "Vitamina D3", "Magnesio"
    var dosage: String                   // Ej: "50 mcg", "2000 UI", "400 mg"
    var frequency: String                // Ej: "Cada mañana en ayunas", "Días alternos"
    var type: MedicationType             // .prescription, .supplement, .asNeeded
    var startDate: Date
    var isCurrent: Bool
    var prescribingDoctor: String?
    var notes: String?

    // MARK: - Registro de tomas (dosis + recordatorios)

    /// Dosis por toma (cantidad exacta, ej: "50 mcg" — distinta de la dosis total diaria)
    var dosePerIntake: String?

    /// Horarios de toma en formato "HH:mm" (ej: ["08:00", "20:00"])
    var intakeTimes: [String]

    /// Recordatorio de toma activado (notificaciones locales)
    var reminderEnabled: Bool

    // MARK: - Efectos secundarios

    /// Efectos secundarios conocidos/experimentados (ej: ["Náuseas leves", "Mareo"])
    var sideEffects: [String]

    /// Registro de efectos secundarios experimentados por el usuario
    var experiencedSideEffects: [String]

    enum MedicationType: String, Codable {
        case prescription = "Prescripción médica"
        case supplement = "Suplemento"
        case asNeeded = "A demanda"
    }

    init(
        name: String,
        dosage: String,
        frequency: String,
        type: MedicationType = .prescription,
        startDate: Date = Date(),
        isCurrent: Bool = true,
        prescribingDoctor: String? = nil,
        notes: String? = nil,
        dosePerIntake: String? = nil,
        intakeTimes: [String] = [],
        reminderEnabled: Bool = false,
        sideEffects: [String] = [],
        experiencedSideEffects: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.type = type
        self.startDate = startDate
        self.isCurrent = isCurrent
        self.prescribingDoctor = prescribingDoctor
        self.notes = notes
        self.dosePerIntake = dosePerIntake
        self.intakeTimes = intakeTimes
        self.reminderEnabled = reminderEnabled
        self.sideEffects = sideEffects
        self.experiencedSideEffects = experiencedSideEffects
    }

    // MARK: - Derivados

    /// Texto legible de los horarios (ej: "08:00 y 20:00")
    var intakeScheduleText: String {
        if intakeTimes.isEmpty { return frequency }
        return intakeTimes.joined(separator: " y ")
    }

    /// Total de tomas al día
    var intakesPerDay: Int {
        max(intakeTimes.count, 1)
    }
}

// MARK: - Registro de Toma Confirmada (dosis tomada)

@Model
final class MedicationDoseLog {
    var id: UUID
    var medicationName: String          // Nombre del medicamento (relación por nombre, SwiftData simple)
    var takenAt: Date                   // Cuándo se tomó
    var dose: String?                   // Dosis tomada (ej: "50 mcg")
    var skipped: Bool                   // true si se marcó como omitida
    var reasonSkipped: String?          // Motivo (efectos secundarios, olvido...)

    init(
        medicationName: String,
        takenAt: Date = Date(),
        dose: String? = nil,
        skipped: Bool = false,
        reasonSkipped: String? = nil
    ) {
        self.id = UUID()
        self.medicationName = medicationName
        self.takenAt = takenAt
        self.dose = dose
        self.skipped = skipped
        self.reasonSkipped = reasonSkipped
    }
}

// MARK: - Registro Rápido de Síntomas (Symptom Log)

@Model
final class SymptomEntry {
    var id: UUID
    var timestamp: Date
    var symptomName: String              // Ej: "Cefalea", "Mareo", "Fatiga matutina"
    var intensity: SymptomIntensity      // .mild, .moderate, .severe
    var durationMinutes: Int?
    var contextTrigger: String?          // Ej: "Postprandial", "Tras mala noche"
    var rawDictation: String?            // Texto original dictado por voz

    enum SymptomIntensity: String, Codable {
        case mild = "Leve"
        case moderate = "Moderada"
        case severe = "Intensa"
    }

    init(
        symptomName: String,
        intensity: SymptomIntensity = .mild,
        durationMinutes: Int? = nil,
        contextTrigger: String? = nil,
        rawDictation: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.symptomName = symptomName
        self.intensity = intensity
        self.durationMinutes = durationMinutes
        self.contextTrigger = contextTrigger
        self.rawDictation = rawDictation
    }
}

// MARK: - Historial y Diario de Consultas Médicas (Post-Visit)

@Model
final class DoctorVisitRecord {
    var id: UUID
    var visitDate: Date
    var doctorName: String?
    var specialty: String                // Ej: "Cardiología", "Medicina General"
    var clinicOrHospital: String?
    var reasonsForVisit: [String]        // Motivos de consulta
    var doctorInstructions: String       // Pautas o indicaciones recibidas
    var nextReviewDate: Date?
    var attachedLabReportId: UUID?

    init(
        specialty: String,
        visitDate: Date = Date(),
        doctorName: String? = nil,
        clinicOrHospital: String? = nil,
        reasonsForVisit: [String] = [],
        doctorInstructions: String = "",
        nextReviewDate: Date? = nil
    ) {
        self.id = UUID()
        self.visitDate = visitDate
        self.specialty = specialty
        self.doctorName = doctorName
        self.clinicOrHospital = clinicOrHospital
        self.reasonsForVisit = reasonsForVisit
        self.doctorInstructions = doctorInstructions
        self.nextReviewDate = nextReviewDate
    }
}

// MARK: - Analíticas de Laboratorio y Biomarcadores Históricos

struct LabResult: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let laboratoryName: String?
    let markers: [LabMarker]
    var source: LabSource
    let rawImageData: Data?

    enum LabSource: String, Codable {
        case ocr = "ocr"
        case fhir = "fhir"
        case manual = "manual"
    }
}

struct LabMarker: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String                  // Ej: "Colesterol LDL", "Ferritina"
    let value: Double
    let unit: String                  // Ej: "mg/dL", "ng/mL"
    let referenceMin: Double?
    let referenceMax: Double?
    var status: MarkerStatus
    var testDate: Date?

    var isInRange: Bool {
        guard let min = referenceMin, let max = referenceMax else { return true }
        return value >= min && value <= max
    }

    enum MarkerStatus: String, Codable {
        case normal, low, high, critical
    }
}

// MARK: - Snapshots de HealthKit (Series Temporales)

struct ActivitySnapshot: Codable, Sendable {
    let date: Date
    let steps: Int
    let activeCalories: Double
    let exerciseMinutes: Int
    let standHours: Int
    let vo2Max: Double?
    let distanceKm: Double
}

struct CardioSnapshot: Codable, Sendable {
    let date: Date
    let restingHeartRate: Double?
    let heartRateVariability: Double?
    let averageHeartRate: Double?
    let peakHeartRate: Double?
}

struct SleepSnapshot: Codable, Sendable {
    let date: Date
    let totalMinutes: Int
    let remMinutes: Int
    let deepMinutes: Int
    let coreMinutes: Int
    let awakMinutes: Int
}

struct NutritionSnapshot: Codable, Sendable {
    let date: Date
    let totalCalories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double?
    let water: Double?
    let meals: [MealEntry]
}

struct MealEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let imageData: Data?
    var source: MealSource

    enum MealSource: String, Codable {
        case photoAI = "photo_ai"
        case barcode = "barcode"
        case manual = "manual"
    }
}

// MARK: - Mensaje de Chat

@Model
final class ChatMessage {
    var id: UUID
    var timestamp: Date
    var role: MessageRole
    var content: String

    enum MessageRole: String, Codable {
        case user, agent
    }

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.role = role
        self.content = content
    }
}


// MARK: - Registro de Peso (tendencia y evolución)

@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weightKg: Double
    var notes: String?

    init(date: Date = Date(), weightKg: Double, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.notes = notes
    }
}

// MARK: - Check-in Diario de Bienestar (estado de ánimo + energía)

@Model
final class DailyCheckIn {
    var id: UUID
    var date: Date
    var mood: MoodLevel         // ánimo general
    var energyLevel: EnergyLevel // energía física
    var sleepQuality: Int       // 1-5
    var notes: String?

    enum MoodLevel: String, Codable, CaseIterable {
        case low = "Bajo"
        case neutral = "Neutro"
        case good = "Bien"
        case great = "Muy bien"

        var emoji: String {
            switch self {
            case .low:     return "😞"
            case .neutral: return "😐"
            case .good:    return "🙂"
            case .great:   return "😄"
            }
        }
    }

    enum EnergyLevel: String, Codable, CaseIterable {
        case low = "Baja"
        case medium = "Media"
        case high = "Alta"

        var emoji: String {
            switch self {
            case .low:    return "🪫"
            case .medium: return "🔋"
            case .high:   return "⚡"
            }
        }
    }

    init(
        date: Date = Date(),
        mood: MoodLevel = .neutral,
        energyLevel: EnergyLevel = .medium,
        sleepQuality: Int = 3,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.mood = mood
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.notes = notes
    }
}


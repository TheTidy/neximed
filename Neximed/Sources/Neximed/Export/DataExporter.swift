// Neximed — DataExporter.swift
// Exporta todos los datos del usuario a CSV y JSON para compartirlos
// con su médico o hacer backup local. 100% on-device.

import Foundation

struct DataExporter {

    static let shared = DataExporter()

    /// Salto de línea para CSV (CRLF, compatible con Excel)
    private var nl: String { Character(13).description + Character(10).description }

    // MARK: - CSV

    func exportCSV(
        profile: UserProfile?,
        activity: [ActivitySnapshot],
        cardio: [CardioSnapshot],
        sleep: [SleepSnapshot],
        nutrition: [NutritionSnapshot],
        weights: [WeightEntry],
        symptoms: [SymptomEntry]
    ) -> String {
        var csv = ""

        if let profile {
            csv += "# PERFIL" + nl
            csv += "Nombre," + profile.name + nl
            if let age = profile.age { csv += "Edad," + String(age) + nl }
            if let sex = profile.biologicalSex { csv += "Sexo," + sex + nl }
            if let bmi = profile.bmi { csv += String(format: "IMC,%.1f", bmi) + nl }
            if !profile.chronicConditions.isEmpty { csv += "Patologías," + profile.chronicConditions.joined(separator: "; ") + nl }
            if !profile.foodAllergens.isEmpty { csv += "Alergias alimentarias," + profile.foodAllergens.map { $0.rawValue }.joined(separator: "; ") + nl }
            if let diet = profile.dietType { csv += "Dieta," + diet + nl }
            if let work = profile.workSchedule { csv += "Trabajo," + work + nl }
            csv += nl
        }

        if !activity.isEmpty {
            csv += "# ACTIVIDAD" + nl
            csv += "Fecha,Pasos,Calorías,Ejercicio (min),Distancia (km)" + nl
            for a in activity {
                csv += a.date.formatted(date: .numeric, time: .omitted) + "," + String(a.steps) + "," + String(Int(a.activeCalories)) + "," + String(a.exerciseMinutes) + "," + String(format: "%.2f", a.distanceKm) + nl
            }
            csv += nl
        }

        if !cardio.isEmpty {
            csv += "# CARDIO" + nl
            csv += "Fecha,FC reposo (bpm),HRV (ms)" + nl
            for c in cardio {
                let rhr = c.restingHeartRate.map { String(format: "%.0f", $0) } ?? ""
                let hrv = c.heartRateVariability.map { String(format: "%.0f", $0) } ?? ""
                csv += c.date.formatted(date: .numeric, time: .omitted) + "," + rhr + "," + hrv + nl
            }
            csv += nl
        }

        if !sleep.isEmpty {
            csv += "# SUEÑO" + nl
            csv += "Fecha,Horas,REM (min),Profundo (min)" + nl
            for s in sleep {
                csv += s.date.formatted(date: .numeric, time: .omitted) + "," + String(format: "%.1f", Double(s.totalMinutes) / 60) + "," + String(s.remMinutes) + "," + String(s.deepMinutes) + nl
            }
            csv += nl
        }

        if !nutrition.isEmpty {
            csv += "# NUTRICIÓN" + nl
            csv += "Fecha,kcal,Proteína (g),Carbos (g),Grasas (g)" + nl
            for n in nutrition {
                csv += n.date.formatted(date: .numeric, time: .omitted) + "," + String(Int(n.totalCalories)) + "," + String(Int(n.protein)) + "," + String(Int(n.carbohydrates)) + "," + String(Int(n.fat)) + nl
            }
            csv += nl
        }

        if !weights.isEmpty {
            csv += "# PESO" + nl
            csv += "Fecha,Peso (kg)" + nl
            for w in weights.sorted(by: { $0.date < $1.date }) {
                csv += w.date.formatted(date: .numeric, time: .omitted) + "," + String(format: "%.1f", w.weightKg) + nl
            }
            csv += nl
        }

        if !symptoms.isEmpty {
            csv += "# SÍNTOMAS" + nl
            csv += "Fecha,Síntoma,Intensidad,Contexto" + nl
            for s in symptoms {
                csv += s.timestamp.formatted(date: .numeric, time: .omitted) + "," + s.symptomName + "," + s.intensity.rawValue + "," + (s.contextTrigger ?? "") + nl
            }
        }

        return csv
    }

    // MARK: - JSON

    func exportJSON(
        profile: UserProfile?,
        activity: [ActivitySnapshot],
        cardio: [CardioSnapshot],
        sleep: [SleepSnapshot],
        nutrition: [NutritionSnapshot],
        weights: [WeightEntry],
        symptoms: [SymptomEntry],
        medications: [MedicationEntry]
    ) -> Data? {
        var dict: [String: Any] = [
            "app": "Neximed",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "version": "1.0"
        ]

        if let profile {
            dict["profile"] = [
                "name": profile.name,
                "age": profile.age as Any,
                "sex": profile.biologicalSex as Any,
                "bloodType": profile.bloodType as Any,
                "allergies": profile.allergies,
                "foodAllergens": profile.foodAllergens.map { $0.rawValue },
                "chronicConditions": profile.chronicConditions,
                "dietType": profile.dietType as Any,
                "workSchedule": profile.workSchedule as Any,
                "heightCm": profile.heightCm as Any,
                "weightKg": profile.weightKg as Any,
                "bmi": profile.bmi as Any
            ]
        }

        dict["activity"] = activity.map { ["date": $0.date.timeIntervalSince1970, "steps": $0.steps, "calories": $0.activeCalories] }
        dict["cardio"] = cardio.map { ["date": $0.date.timeIntervalSince1970, "restingHR": $0.restingHeartRate as Any, "hrv": $0.heartRateVariability as Any] }
        dict["sleep"] = sleep.map { ["date": $0.date.timeIntervalSince1970, "totalMinutes": $0.totalMinutes, "rem": $0.remMinutes, "deep": $0.deepMinutes] }
        dict["nutrition"] = nutrition.map { ["date": $0.date.timeIntervalSince1970, "calories": $0.totalCalories, "protein": $0.protein, "carbs": $0.carbohydrates, "fat": $0.fat] }
        dict["weights"] = weights.map { ["date": $0.date.timeIntervalSince1970, "weightKg": $0.weightKg] }
        dict["symptoms"] = symptoms.map { ["date": $0.timestamp.timeIntervalSince1970, "symptom": $0.symptomName, "intensity": $0.intensity.rawValue, "context": $0.contextTrigger as Any] }
        dict["medications"] = medications.map { ["name": $0.name, "dosage": $0.dosage, "frequency": $0.frequency, "type": $0.type.rawValue] }

        return try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }
}
// Neximed — WellnessRecommendations.swift
// Genera recomendaciones de estilo de vida SEGURAS comparando los datos
// del usuario con sus propios objetivos. NUNCA emite diagnósticos ni
// consejo médico: solo patrones observacionales y datos vs. objetivos.

import Foundation

struct WellnessRecommendation: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let type: RecommendationType

    enum RecommendationType: Sendable {
        case sleep, activity, hydration, nutrition, recovery

        var icon: String {
            switch self {
            case .sleep:      return "moon.stars.fill"
            case .activity:   return "figure.walk"
            case .hydration:  return "drop.fill"
            case .nutrition:  return "fork.knife"
            case .recovery:   return "waveform.path.ecg"
            }
        }

        var color: String {
            switch self {
            case .sleep:      return "sleep"
            case .activity:   return "activity"
            case .hydration:  return "labs"
            case .nutrition:  return "nutrition"
            case .recovery:   return "cardio"
            }
        }
    }
}

struct WellnessRecommendations {

    static let shared = WellnessRecommendations()

    func generate(
        sleep: [SleepSnapshot],
        cardio: [CardioSnapshot],
        activity: [ActivitySnapshot],
        nutrition: [NutritionSnapshot],
        profile: UserProfile?
    ) -> [WellnessRecommendation] {
        var recommendations: [WellnessRecommendation] = []

        // --- Sueño ---
        if !sleep.isEmpty {
            let avgHours = sleep.map { Double($0.totalMinutes) / 60.0 }.reduce(0, +) / Double(sleep.count)
            let goal = profile?.goalSleepHours ?? 7.5
            if avgHours < goal - 0.5 {
                recommendations.append(WellnessRecommendation(
                    title: "Descanso bajo tu objetivo",
                    message: String(format: "Duermes %.1f h de media; tu objetivo son %.1f h. Comenta tu patrón de sueño con tu médico si te preocupa.", avgHours, goal),
                    type: .sleep
                ))
            } else if avgHours >= goal {
                recommendations.append(WellnessRecommendation(
                    title: "Buen descanso",
                    message: String(format: "Estás cumpliendo tu objetivo de sueño (%.1f h). Sigue así para mantener tu recuperación.", avgHours),
                    type: .sleep
                ))
            }
        }

        // --- Actividad ---
        if !activity.isEmpty {
            let avgSteps = activity.map { Double($0.steps) }.reduce(0, +) / Double(activity.count)
            let goal = Double(profile?.goalSteps ?? 10000)
            if avgSteps < goal * 0.7 {
                recommendations.append(WellnessRecommendation(
                    title: "Actividad por debajo de tu objetivo",
                    message: String(format: "Promedias %.0f pasos/día frente a tu objetivo de %.0f. Pequeños paseos diarios ayudan a acercarte.", avgSteps, goal),
                    type: .activity
                ))
            } else {
                recommendations.append(WellnessRecommendation(
                    title: "Buena actividad",
                    message: String(format: "Promedias %.0f pasos/día, cerca de tu objetivo de %.0f.", avgSteps, goal),
                    type: .activity
                ))
            }
        }

        // --- Hidratación ---
        if let water = profile?.waterIntakeLiters {
            if water < 1.5 {
                recommendations.append(WellnessRecommendation(
                    title: "Hidratación mejorable",
                    message: String(format: "Has registrado %.1f L de agua al día. Aumentar la ingesta suele mejorar la energía.", water),
                    type: .hydration
                ))
            }
        }

        // --- Nutrición ---
        if !nutrition.isEmpty {
            let avgProtein = nutrition.map { $0.protein }.reduce(0, +) / Double(nutrition.count)
            let goal = profile?.goalProtein ?? 60
            if avgProtein < goal * 0.8 && avgProtein > 0 {
                recommendations.append(WellnessRecommendation(
                    title: "Proteína por debajo de tu objetivo",
                    message: String(format: "Promedias %.0f g de proteína/día frente a tu objetivo de %.0f g.", avgProtein, goal),
                    type: .nutrition
                ))
            }
        }

        // --- Recuperación (HRV) ---
        if !cardio.isEmpty {
            let hrvs = cardio.compactMap { $0.heartRateVariability }
            if !hrvs.isEmpty {
                let avgHRV = hrvs.reduce(0, +) / Double(hrvs.count)
                if avgHRV < 30 {
                    recommendations.append(WellnessRecommendation(
                        title: "Recuperación a vigilar",
                        message: String(format: "Tu HRV medio es %.0f ms. Es un valor orientativo: coméntalo con tu médico si lo consideras relevante.", avgHRV),
                        type: .recovery
                    ))
                }
            }
        }

        return recommendations
    }
}

// MARK: - Extensión para media

private extension [Double] {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
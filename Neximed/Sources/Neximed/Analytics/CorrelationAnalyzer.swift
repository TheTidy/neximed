// Neximed — CorrelationAnalyzer.swift
// Analiza correlaciones entre los datos recopilados (100% on-device)
// para mostrar patrones observacionales al usuario.
//
// IMPORTANTE: las correlaciones son OBSERVACIONALES e informativas.
// No implican causalidad ni diagnóstico — solo patrones de los propios datos.

import Foundation

struct CorrelationResult: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let strength: Strength   // fuerza de la correlación

    enum Strength: Sendable {
        case strong, moderate, weak, none

        var label: String {
            switch self {
            case .strong:   return "Correlación notable"
            case .moderate: return "Correlación moderada"
            case .weak:     return "Correlación leve"
            case .none:     return "Sin correlación clara"
            }
        }
    }
}

struct CorrelationAnalyzer {

    static let shared = CorrelationAnalyzer()

    /// Calcula el coeficiente de correlación de Pearson entre dos series diarias
    /// alineadas por fecha. Devuelve nil si no hay suficientes pares (>= 4).
    func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 4 else { return nil }

        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var num = 0.0
        var denX = 0.0
        var denY = 0.0
        for i in 0..<xs.count {
            let dx = xs[i] - meanX
            let dy = ys[i] - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }

        guard denX > 0, denY > 0 else { return nil }
        return num / sqrt(denX * denY)
    }

    private func strength(for r: Double) -> CorrelationResult.Strength {
        let absR = abs(r)
        if absR >= 0.5 { return .strong }
        if absR >= 0.3 { return .moderate }
        if absR >= 0.1 { return .weak }
        return .none
    }

    /// Analiza todas las correlaciones disponibles con los datos cacheados
    func analyze(sleep: [SleepSnapshot], cardio: [CardioSnapshot], activity: [ActivitySnapshot]) -> [CorrelationResult] {
        var results: [CorrelationResult] = []

        // Diccionario por fecha para alinear las series
        func key(_ d: Date) -> Date {
            Calendar.current.startOfDay(for: d)
        }

        // 1. Sueño ↔ HRV (más sueño → ¿mejor variabilidad?)
        let sleepHRV = alignedPairs(
            datesA: sleep.map { key($0.date) }, valuesA: sleep.map { Double($0.totalMinutes) },
            datesB: cardio.map { key($0.date) }, valuesB: cardio.compactMap { $0.heartRateVariability }
        )
        if let r = pearson(sleepHRV.xs, sleepHRV.ys) {
            let direction = r > 0 ? "más horas de sueño" : "menos horas de sueño"
            results.append(CorrelationResult(
                title: "Sueño y variabilidad cardíaca (HRV)",
                description: "En tus datos, \(direction) se asocia con mayor HRV (recuperación).",
                strength: strength(for: r)
            ))
        }

        // 2. Pasos ↔ FC en reposo (más actividad → ¿menor FC reposo?)
        let stepsRHR = alignedPairs(
            datesA: activity.map { key($0.date) }, valuesA: activity.map { Double($0.steps) },
            datesB: cardio.map { key($0.date) }, valuesB: cardio.compactMap { $0.restingHeartRate }
        )
        if let r = pearson(stepsRHR.xs, stepsRHR.ys) {
            let direction = r < 0 ? "más pasos" : "menos pasos"
            results.append(CorrelationResult(
                title: "Actividad y frecuencia cardíaca en reposo",
                description: "En tus datos, \(direction) se asocian con una FC en reposo más baja.",
                strength: strength(for: r)
            ))
        }

        // 3. Sueño ↔ Pasos (¿los días con más pasos duermes más o menos?)
        let sleepSteps = alignedPairs(
            datesA: sleep.map { key($0.date) }, valuesA: sleep.map { Double($0.totalMinutes) },
            datesB: activity.map { key($0.date) }, valuesB: activity.map { Double($0.steps) }
        )
        if let r = pearson(sleepSteps.xs, sleepSteps.ys) {
            let desc: String
            if r > 0.1 {
                desc = "Los días con más pasos suelen coincidir con noches de más sueño en tus datos."
            } else if r < -0.1 {
                desc = "Los días con más pasos suelen coincidir con noches de menos sueño en tus datos."
            } else {
                desc = "No se observa una relación clara entre tus pasos y tu sueño."
            }
            results.append(CorrelationResult(
                title: "Actividad y sueño",
                description: desc,
                strength: strength(for: r)
            ))
        }

        return results
    }

    /// Alinea dos series por fecha, devolviendo pares (x, y) donde ambas existen
    private func alignedPairs(
        datesA: [Date], valuesA: [Double],
        datesB: [Date], valuesB: [Double]
    ) -> (xs: [Double], ys: [Double]) {
        var dictB: [Date: Double] = [:]
        for (i, d) in datesB.enumerated() {
            dictB[d] = valuesB[i]
        }

        var xs: [Double] = []
        var ys: [Double] = []
        for (i, d) in datesA.enumerated() {
            if let b = dictB[d] {
                xs.append(valuesA[i])
                ys.append(b)
            }
        }
        return (xs, ys)
    }
}
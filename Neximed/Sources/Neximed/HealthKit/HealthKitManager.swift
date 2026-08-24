// Neximed — HealthKitManager.swift
// Capa de acceso a HealthKit: autorización, queries y escritura de datos

import HealthKit
import Foundation
import Observation

@MainActor
@Observable
final class HealthKitManager {

    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    var isAuthorized = false
    var lastError: Error?

    // MARK: - Cache de datos precargados (para arranque instantáneo)
    // Se rellenan durante el splash (AppBootstrapper) para que el Dashboard
    // muestre los datos al instante sin esperar queries.

    private(set) var cachedActivity: [ActivitySnapshot] = []
    private(set) var cachedCardio: [CardioSnapshot] = []
    private(set) var cachedSleep: [SleepSnapshot] = []
    private(set) var cachedNutrition: [NutritionSnapshot] = []
    private(set) var didPreload = false

    /// Precarga todos los datos de los últimos días (llamado desde el splash).
    /// Reporta progreso real (0.0 a 1.0) a medida que cada query de HealthKit
    /// completa — así la barra de carga refleja el trabajo REAL, no estimaciones.
    func preloadData(days: Int = 14, onProgress: ((Double) -> Void)? = nil) async {
        // Resultado tipado de cada query: qué datos llegaron
        enum PreloadResult {
            case activity([ActivitySnapshot])
            case cardio([CardioSnapshot])
            case sleep([SleepSnapshot])
            case nutrition([NutritionSnapshot])
        }

        let totalQueries = 4
        var completed = 0

        // TaskGroup canónico: cada tarea devuelve su resultado; el for await
        // los procesa en el orden en que llegan (sin variables compartidas mutables)
        await withTaskGroup(of: PreloadResult.self) { group in
            group.addTask {
                let data = (try? await self.fetchActivitySummary(for: days)) ?? []
                return .activity(data)
            }
            group.addTask {
                let data = (try? await self.fetchCardioSummary(for: days)) ?? []
                return .cardio(data)
            }
            group.addTask {
                let data = (try? await self.fetchSleepSummary(for: days)) ?? []
                return .sleep(data)
            }
            group.addTask {
                let data = (try? await self.fetchNutritionSummary(for: days)) ?? []
                return .nutrition(data)
            }

            for await result in group {
                switch result {
                case .activity(let data): cachedActivity = data
                case .cardio(let data):  cachedCardio = data
                case .sleep(let data):   cachedSleep = data
                case .nutrition(let data): cachedNutrition = data
                }
                completed += 1
                onProgress?(Double(completed) / Double(totalQueries))
            }
        }

        didPreload = true
    }

    /// Limpia el cache (por si el usuario revoca permisos o cambian los datos)
    func invalidateCache() {
        cachedActivity = []
        cachedCardio = []
        cachedSleep = []
        cachedNutrition = []
        didPreload = false
    }

    // MARK: - Tipos de datos que necesitamos leer

    private let readTypes: Set<HKObjectType> = {
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            // Actividad
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleStandTime,
            .vo2Max,
            .distanceWalkingRunning,
            // Cardio
            .heartRate,
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .walkingHeartRateAverage,
            // Sueño (via categoría)
            // Nutrición
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietarySugar,
            .dietaryWater,
            .dietarySodium,
            // Cuerpo
            .bodyMass,
            .bodyMassIndex,
            .bodyFatPercentage,
            .leanBodyMass,
            .bodyTemperature,
            // Lab / Sangre
            .bloodGlucose,
            .oxygenSaturation,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
        ]

        var types: Set<HKObjectType> = Set(
            quantityTypes.compactMap { HKQuantityType($0) }
        )

        // Tipos de categoría
        if let sleepType = HKCategoryType(.sleepAnalysis) {
            types.insert(sleepType)
        }
        if let mindfulType = HKCategoryType(.mindfulSession) {
            types.insert(mindfulType)
        }
        // ECG
        if let ecgType = HKElectrocardiogramType.electrocardiogramType() {
            types.insert(ecgType)
        }
        // NOTA: los registros clínicos FHIR (HKClinicalType) requieren el
        // entitlement especial "health-records" aprobado por Apple.
        // Se añadirán en Fase 3 (exportación FHIR JSON) para no bloquear la revisión.
        return types
    }()

    // Tipos que también necesitamos escribir (nutrición)
    private let writeTypes: Set<HKSampleType> = {
        let nutritionIds: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .dietaryProtein,
            .dietaryCarbohydrates, .dietaryFatTotal,
            .dietaryFiber, .dietaryWater
        ]
        return Set(nutritionIds.compactMap { HKQuantityType($0) })
    }()

    // MARK: - Autorización

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        isAuthorized = true
    }

    // MARK: - Queries de Actividad

    func fetchActivitySummary(for days: Int = 7) async throws -> [ActivitySnapshot] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -days, to: end)!

        async let steps = fetchDailyQuantities(.stepCount, from: start, to: end, unit: .count())
        async let calories = fetchDailyQuantities(.activeEnergyBurned, from: start, to: end, unit: .kilocalorie())
        async let exercise = fetchDailyQuantities(.appleExerciseTime, from: start, to: end, unit: .minute())
        async let distance = fetchDailyQuantities(.distanceWalkingRunning, from: start, to: end, unit: .meterUnit(with: .kilo))

        let (stepsData, caloriesData, exerciseData, distanceData) = try await (steps, calories, exercise, distance)

        var snapshots: [ActivitySnapshot] = []
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: end)!
            let dateKey = calendar.startOfDay(for: date)
            snapshots.append(ActivitySnapshot(
                date: dateKey,
                steps: Int(stepsData[dateKey] ?? 0),
                activeCalories: caloriesData[dateKey] ?? 0,
                exerciseMinutes: Int(exerciseData[dateKey] ?? 0),
                standHours: 0, // requiere HKActivitySummaryQuery separado
                vo2Max: nil,
                distanceKm: distanceData[dateKey] ?? 0
            ))
        }
        return snapshots.sorted { $0.date < $1.date }
    }

    // MARK: - Queries de Cardio

    func fetchCardioSummary(for days: Int = 7) async throws -> [CardioSnapshot] {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end)!

        async let hrv = fetchDailyQuantities(.heartRateVariabilitySDNN, from: start, to: end, unit: HKUnit(from: "ms"))
        async let rhr = fetchDailyQuantities(.restingHeartRate, from: start, to: end, unit: .count().unitDivided(by: .minute()))
        async let avgHR = fetchDailyQuantities(.walkingHeartRateAverage, from: start, to: end, unit: .count().unitDivided(by: .minute()))

        let (hrvData, rhrData, avgHRData) = try await (hrv, rhr, avgHR)

        var snapshots: [CardioSnapshot] = []
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: end)!
            let dateKey = calendar.startOfDay(for: date)
            snapshots.append(CardioSnapshot(
                date: dateKey,
                restingHeartRate: rhrData[dateKey],
                heartRateVariability: hrvData[dateKey],
                averageHeartRate: avgHRData[dateKey],
                peakHeartRate: nil,
                ecgClassification: nil
            ))
        }
        return snapshots.sorted { $0.date < $1.date }
    }

    // MARK: - Queries de Sueño

    func fetchSleepSummary(for days: Int = 7) async throws -> [SleepSnapshot] {
        guard let sleepType = HKCategoryType(.sleepAnalysis) else {
            throw HealthKitError.typeUnavailable
        }

        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // Agrupa por noche (día anterior al despertar)
                var byNight: [Date: [HKCategorySample]] = [:]
                for sample in categorySamples {
                    let night = calendar.startOfDay(for: sample.endDate)
                    byNight[night, default: []].append(sample)
                }

                let snapshots: [SleepSnapshot] = byNight.compactMap { (date, samples) in
                    var rem = 0, deep = 0, core = 0, awake = 0
                    for s in samples {
                        let minutes = Int(s.endDate.timeIntervalSince(s.startDate) / 60)
                        switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                        case .asleepREM:   rem   += minutes
                        case .asleepDeep: deep  += minutes
                        case .asleepCore: core  += minutes
                        case .awake:      awake += minutes
                        default: break
                        }
                    }
                    let total = rem + deep + core
                    guard total > 0 else { return nil }
                    return SleepSnapshot(
                        date: date,
                        totalMinutes: total,
                        remMinutes: rem,
                        deepMinutes: deep,
                        coreMinutes: core,
                        awakMinutes: awake,
                        sleepScore: nil,
                        consistencyScore: nil
                    )
                }
                continuation.resume(returning: snapshots.sorted { $0.date < $1.date })
            }
            store.execute(query)
        }
    }

    // MARK: - Queries de Nutrición

    func fetchNutritionSummary(for days: Int = 7) async throws -> [NutritionSnapshot] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -days, to: end)!

        async let calories = fetchDailyQuantities(.dietaryEnergyConsumed, from: start, to: end, unit: .kilocalorie())
        async let protein = fetchDailyQuantities(.dietaryProtein, from: start, to: end, unit: .gram())
        async let carbs = fetchDailyQuantities(.dietaryCarbohydrates, from: start, to: end, unit: .gram())
        async let fat = fetchDailyQuantities(.dietaryFatTotal, from: start, to: end, unit: .gram())
        async let fiber = fetchDailyQuantities(.dietaryFiber, from: start, to: end, unit: .gram())
        async let water = fetchDailyQuantities(.dietaryWater, from: start, to: end, unit: .liter())

        let (cData, pData, carbData, fatData, fiberData, waterData) =
            try await (calories, protein, carbs, fat, fiber, water)

        var snapshots: [NutritionSnapshot] = []
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: end)!
            let dateKey = calendar.startOfDay(for: date)
            snapshots.append(NutritionSnapshot(
                date: dateKey,
                totalCalories: cData[dateKey] ?? 0,
                protein: pData[dateKey] ?? 0,
                carbohydrates: carbData[dateKey] ?? 0,
                fat: fatData[dateKey] ?? 0,
                fiber: fiberData[dateKey],
                sugar: nil,
                water: waterData[dateKey],
                sodium: nil,
                meals: []
            ))
        }
        return snapshots.sorted { $0.date < $1.date }
    }

    // MARK: - Escritura de Nutrición

    func logMeal(_ meal: MealEntry) async throws {
        var samples: [HKQuantitySample] = []
        let metadata: [String: Any] = [HKMetadataKeyFoodType: meal.name]

        func makeSample(_ id: HKQuantityTypeIdentifier, value: Double, unit: HKUnit) -> HKQuantitySample? {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            return HKQuantitySample(type: type, quantity: quantity, start: meal.timestamp, end: meal.timestamp, metadata: metadata)
        }

        if let s = makeSample(.dietaryEnergyConsumed, value: meal.calories, unit: .kilocalorie()) { samples.append(s) }
        if let s = makeSample(.dietaryProtein, value: meal.protein, unit: .gram()) { samples.append(s) }
        if let s = makeSample(.dietaryCarbohydrates, value: meal.carbs, unit: .gram()) { samples.append(s) }
        if let s = makeSample(.dietaryFatTotal, value: meal.fat, unit: .gram()) { samples.append(s) }

        try await store.save(samples)
    }

    // MARK: - Helpers privados

    private func fetchDailyQuantities(
        _ identifier: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async throws -> [Date: Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.typeUnavailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: identifier == .heartRate || identifier == .heartRateVariabilitySDNN
                    ? .discreteAverage : .cumulativeSum,
                anchorDate: calendar.startOfDay(for: end),
                intervalComponents: components
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var dict: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: unit)
                        ?? statistics.averageQuantity()?.doubleValue(for: unit)
                    if let value {
                        dict[calendar.startOfDay(for: statistics.startDate)] = value
                    }
                }
                continuation.resume(returning: dict)
            }
            store.execute(query)
        }
    }

    // MARK: - Estado de salud agregado (para el agente)

    struct HealthContext {
        let activity: [ActivitySnapshot]
        let cardio: [CardioSnapshot]
        let sleep: [SleepSnapshot]
        let nutrition: [NutritionSnapshot]
        let generatedAt: Date

        var summaryForAgent: String {
            """
            === CONTEXTO DE SALUD DEL USUARIO (últimos 7 días) ===
            Fecha de análisis: \(generatedAt.formatted())

            ACTIVIDAD:
            - Pasos promedio/día: \(activity.map(\.steps).average.formatted(.number.precision(.fractionLength(0))))
            - Calorías activas promedio/día: \(activity.map(\.activeCalories).average.formatted(.number.precision(.fractionLength(0)))) kcal
            - Minutos de ejercicio/día: \(activity.map { Double($0.exerciseMinutes) }.average.formatted(.number.precision(.fractionLength(0))))

            SUEÑO:
            - Horas promedio/noche: \(sleep.map { Double($0.totalMinutes) / 60.0 }.average.formatted(.number.precision(.fractionLength(1))))h
            - REM promedio: \(sleep.map { Double($0.remMinutes) }.average.formatted(.number.precision(.fractionLength(0)))) min
            - Sueño profundo promedio: \(sleep.map { Double($0.deepMinutes) }.average.formatted(.number.precision(.fractionLength(0)))) min

            CARDIO:
            - FC en reposo promedio: \(cardio.compactMap(\.restingHeartRate).average.formatted(.number.precision(.fractionLength(0)))) bpm
            - HRV promedio: \(cardio.compactMap(\.heartRateVariability).average.formatted(.number.precision(.fractionLength(1)))) ms

            NUTRICIÓN:
            - Calorías promedio/día: \(nutrition.map(\.totalCalories).average.formatted(.number.precision(.fractionLength(0)))) kcal
            - Proteínas promedio/día: \(nutrition.map(\.protein).average.formatted(.number.precision(.fractionLength(0)))) g
            - Carbohidratos promedio/día: \(nutrition.map(\.carbohydrates).average.formatted(.number.precision(.fractionLength(0)))) g
            - Grasas promedio/día: \(nutrition.map(\.fat).average.formatted(.number.precision(.fractionLength(0)))) g
            """
        }
    }

    func buildHealthContext(days: Int = 7) async throws -> HealthContext {
        async let activity = fetchActivitySummary(for: days)
        async let cardio = fetchCardioSummary(for: days)
        async let sleep = fetchSleepSummary(for: days)
        async let nutrition = fetchNutritionSummary(for: days)

        return try await HealthContext(
            activity: activity,
            cardio: cardio,
            sleep: sleep,
            nutrition: nutrition,
            generatedAt: Date()
        )
    }

    // MARK: - Errores

    enum HealthKitError: LocalizedError {
        case notAvailable
        case typeUnavailable
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .notAvailable:  return "HealthKit no está disponible en este dispositivo"
            case .typeUnavailable: return "El tipo de dato solicitado no está disponible"
            case .unauthorized: return "El usuario no ha concedido permisos de HealthKit"
            }
        }
    }
}

// MARK: - Extension Array para media

private extension [Double] {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

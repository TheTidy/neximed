// Neximed — NeximedTests.swift
// Tests unitarios de la lógica pura: correlaciones (Pearson), recomendaciones
// de bienestar e historial de analíticas (comparativa longitudinal).

import XCTest
@testable import Neximed

// MARK: - Correlaciones (Pearson)

final class CorrelationAnalyzerTests: XCTestCase {

    private var analyzer: CorrelationAnalyzer { CorrelationAnalyzer() }

    func testPearsonPerfectPositive() {
        let r = analyzer.pearson([1, 2, 3, 4], [2, 4, 6, 8])
        XCTAssertNotNil(r, "Datos perfectamente correlacionados deben dar coeficiente")
        XCTAssertEqual(r!, 1.0, accuracy: 1e-9)
    }

    func testPearsonPerfectNegative() {
        let r = analyzer.pearson([1, 2, 3, 4], [8, 6, 4, 2])
        XCTAssertEqual(r!, -1.0, accuracy: 1e-9)
    }

    func testPearsonAntiCorrelatedLongerSeries() {
        let r = analyzer.pearson([1, 2, 3, 4, 5], [5, 4, 3, 2, 1])
        XCTAssertEqual(r!, -1.0, accuracy: 1e-9)
    }

    func testPearsonConstantSeriesIsNil() {
        // Desviación cero -> coeficiente indefinido
        XCTAssertNil(analyzer.pearson([1, 2, 3], [1, 1, 1]))
        XCTAssertNil(analyzer.pearson([1, 1, 1], [1, 2, 3]))
    }

    func testPearsonEmptyOrMismatchedIsNil() {
        XCTAssertNil(analyzer.pearson([], []))
        XCTAssertNil(analyzer.pearson([1, 2], []))
        XCTAssertNil(analyzer.pearson([1], [1, 2]))
    }
}

// MARK: - Historial de analíticas (LabHistoryStore)

@MainActor
final class LabHistoryStoreTests: XCTestCase {

    private var store: LabHistoryStore!

    override func setUp() {
        super.setUp()
        store = LabHistoryStore.shared
        store.removeAll()
    }

    override func tearDown() {
        store.removeAll()
        super.tearDown()
    }

    private func marker(_ name: String, value: Double) -> LabMarker {
        LabMarker(
            id: UUID(),
            name: name,
            value: value,
            unit: "mg/dL",
            referenceMin: 10,
            referenceMax: 100,
            status: .normal,
            testDate: nil
        )
    }

    private func result(daysAgo: Double, markers: [LabMarker]) -> LabResult {
        LabResult(
            id: UUID(),
            date: Date().addingTimeInterval(-daysAgo * 86400),
            laboratoryName: nil,
            markers: markers,
            source: .ocr,
            rawImageData: nil
        )
    }

    func testAddAndMarkerNamesDeduplicated() {
        store.add(result(daysAgo: 1, markers: [marker("Colesterol", value: 200), marker("Ferritina", value: 30)]))
        store.add(result(daysAgo: 30, markers: [marker("Colesterol", value: 210)]))

        XCTAssertEqual(store.results.count, 2)
        XCTAssertEqual(store.markerNames, ["Colesterol", "Ferritina"], "Nombres únicos en orden de aparición")
    }

    func testSeriesChronologicalOldestFirst() {
        let m = marker("Glucosa", value: 90)
        store.add(result(daysAgo: 1, markers: [m]))
        store.add(result(daysAgo: 30, markers: [m]))

        let series = store.series(for: "Glucosa")
        XCTAssertEqual(series.count, 2)
        XCTAssertLessThan(series[0].date, series[1].date, "La serie debe ordenarse de más antigua a más reciente")
    }

    func testDuplicateIDNotDoubleAdded() {
        let r = result(daysAgo: 1, markers: [marker("Vitamina D", value: 32)])
        store.add(r)
        store.add(r)
        XCTAssertEqual(store.results.count, 1, "Rescaneo de la misma analítica no debe duplicar")
    }

    func testLoadAfterAddKeepsData() {
        store.add(result(daysAgo: 1, markers: [marker("Hierro", value: 80)]))
        store.load()
        XCTAssertEqual(store.results.count, 1, "Los datos persisten (JSON en UserDefaults)")
    }

    func testMarkerPointRangeStatus() {
        let m = LabMarker(
            id: UUID(),
            name: "Potasio",
            value: 120,
            unit: "mg/dL",
            referenceMin: 10,
            referenceMax: 100,
            status: .normal,
            testDate: nil
        )
        store.add(result(daysAgo: 1, markers: [m]))
        let point = store.series(for: "Potasio").first
        XCTAssertNotNil(point)
        XCTAssertFalse(point!.isInRange, "Valor fuera de rango de referencia debe marcarse como tal")
    }
}

// MARK: - Recomendaciones de bienestar

final class WellnessRecommendationsTests: XCTestCase {

    func testSleepRecommendationWhenBelowGoal() {
        // 6 horas de sueño (360 min) < objetivo por defecto 7,5 h - 0,5
        let sleep = [SleepSnapshot(date: Date(), totalMinutes: 360, remMinutes: 90, deepMinutes: 60, coreMinutes: 180, awakMinutes: 30)]
        let recs = WellnessRecommendations.shared.generate(sleep: sleep, cardio: [], activity: [], nutrition: [], profile: nil)

        let rec = recs.first { rec in
            if case .sleep = rec.type { return true }
            return false
        }
        XCTAssertNotNil(rec, "Con 6h de sueño debe emitirse una recomendación de descanso")
        XCTAssertEqual(rec?.title, "Descanso bajo tu objetivo", "Debe ser la recomendación negativa (por debajo del objetivo)")
    }

    func testSleepPositiveRecommendationWhenGoalMet() {
        // 8 horas (480 min) >= objetivo por defecto 7,5 h
        let sleep = [SleepSnapshot(date: Date(), totalMinutes: 480, remMinutes: 120, deepMinutes: 90, coreMinutes: 240, awakMinutes: 30)]
        let recs = WellnessRecommendations.shared.generate(sleep: sleep, cardio: [], activity: [], nutrition: [], profile: nil)

        let rec = recs.first { rec in
            if case .sleep = rec.type { return true }
            return false
        }
        XCTAssertNotNil(rec, "Con el objetivo cumplido se emite un refuerzo positivo")
        XCTAssertEqual(rec?.title, "Buen descanso", "Debe ser la recomendación positiva (objetivo cumplido)")
    }

    func testEmptyDataProducesNoRecommendations() {
        let recs = WellnessRecommendations.shared.generate(sleep: [], cardio: [], activity: [], nutrition: [], profile: nil)
        XCTAssertEqual(recs.count, 0)
    }
}

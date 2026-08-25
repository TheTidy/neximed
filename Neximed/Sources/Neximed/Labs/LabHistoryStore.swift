// Neximed — LabHistoryStore.swift
// Persistencia del historial de analíticas escaneadas (100% on-device, JSON en UserDefaults).
//
// Los resultados se guardan SIN la imagen original (rawImageData = nil) para mantener
// el almacén ligero: la foto completa solo vive en memoria durante la sesión actual.
// Al rescate: permite la comparativa longitudinal de biomarcadores a lo largo del tiempo.

import Foundation
import Observation

@MainActor
@Observable
final class LabHistoryStore {

    static let shared = LabHistoryStore()

    private let storageKey = "neximed.labHistory.v1"
    private let defaults = UserDefaults.standard

    /// Historial completo, más reciente primero
    private(set) var results: [LabResult] = []

    private init() {
        load()
    }

    // MARK: - Persistencia

    func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LabResult].self, from: data) else {
            results = []
            return
        }
        results = decoded.sorted { $0.date > $1.date }
    }

    private func persist() {
        // Copia ligera sin imágenes para no inflar UserDefaults
        let light = results.map { r in
            LabResult(
                id: r.id,
                date: r.date,
                laboratoryName: r.laboratoryName,
                markers: r.markers,
                source: r.source,
                rawImageData: nil
            )
        }
        if let data = try? JSONEncoder().encode(light) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Mutación

    func add(_ result: LabResult) {
        // Evitar duplicados por id (ej. rescaneo de la misma analítica)
        results.removeAll { $0.id == result.id }
        results.append(result)
        results.sort { $0.date > $1.date }
        persist()
    }

    func removeAll() {
        results = []
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: - Consultas para la comparativa longitudinal

    /// Nombres de marcadores presentes en el historial (en orden de aparición)
    var markerNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for result in results {
            for marker in result.markers where !marker.name.isEmpty {
                if seen.insert(marker.name).inserted {
                    names.append(marker.name)
                }
            }
        }
        return names
    }

    /// Punto temporal de un marcador (fecha de la analítica, valor y referencia)
    struct MarkerPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let unit: String
        let referenceMin: Double?
        let referenceMax: Double?

        var isInRange: Bool {
            guard let min = referenceMin, let max = referenceMax else { return true }
            return value >= min && value <= max
        }
    }

    /// Serie temporal de un marcador, ordenada cronológicamente (antiguo -> reciente)
    func series(for markerName: String) -> [MarkerPoint] {
        var points: [MarkerPoint] = []
        for result in results {
            if let marker = result.markers.first(where: { $0.name == markerName }) {
                points.append(
                    MarkerPoint(
                        date: result.date,
                        value: marker.value,
                        unit: marker.unit,
                        referenceMin: marker.referenceMin,
                        referenceMax: marker.referenceMax
                    )
                )
            }
        }
        return points.sorted { $0.date < $1.date }
    }
}

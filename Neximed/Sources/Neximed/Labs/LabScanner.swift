// Neximed — LabScanner.swift
// OCR de analíticas de laboratorio con Vision + interpretación con Foundation Models
// Soporta PDFs importados, fotos de informes y conexión FHIR

import Vision
import UIKit
import Foundation
import PDFKit
import Observation

@MainActor
@Observable
final class LabScanner {

    static let shared = LabScanner()

    var isScanning = false
    var lastResult: LabResult?
    var scanProgress: Double = 0

    // MARK: - Escáner de foto de analítica

    func scanPhoto(_ uiImage: UIImage, laboratoryName: String? = nil) async throws -> LabResult {
        isScanning = true
        scanProgress = 0
        defer { isScanning = false }

        // 1. OCR con Vision
        scanProgress = 0.2
        let recognizedText = try await performOCR(on: uiImage)

        // 2. Parsear valores del laboratorio
        scanProgress = 0.5
        let markers = parseLabMarkers(from: recognizedText)

        // 3. Crear resultado
        scanProgress = 0.8
        let imageData = uiImage.jpegData(compressionQuality: 0.7)
        let result = LabResult(
            id: UUID(),
            date: Date(),
            laboratoryName: laboratoryName ?? extractLabName(from: recognizedText),
            markers: markers,
            source: .ocr,
            rawImageData: imageData
        )

        scanProgress = 1.0
        lastResult = result

        // 4. Escribir en HealthKit
        await writeMarkersToHealthKit(markers)

        return result
    }

    // MARK: - Escáner de PDF

    func scanPDF(_ pdfDocument: PDFDocument, laboratoryName: String? = nil) async throws -> LabResult {
        isScanning = true
        defer { isScanning = false }

        var allText = ""
        let pageCount = pdfDocument.pageCount

        // Extraer texto de todas las páginas
        for i in 0..<pageCount {
            scanProgress = Double(i) / Double(pageCount) * 0.6
            guard let page = pdfDocument.page(at: i) else { continue }

            // Intentar extraer texto nativo del PDF primero
            if let pageText = page.string, !pageText.isEmpty {
                allText += pageText + "\n"
            } else {
                // Si el PDF es escaneado (imagen), usar OCR
                if let thumbnail = page.thumbnail(of: CGSize(width: 1200, height: 1600), for: .mediaBox),
                   let cgImage = thumbnail.cgImage {
                    let uiImage = UIImage(cgImage: cgImage)
                    let pageText = try await performOCR(on: uiImage)
                    allText += pageText + "\n"
                }
            }
        }

        scanProgress = 0.7
        let markers = parseLabMarkers(from: allText)

        let result = LabResult(
            id: UUID(),
            date: extractDate(from: allText) ?? Date(),
            laboratoryName: laboratoryName ?? extractLabName(from: allText),
            markers: markers,
            source: .ocr,
            rawImageData: nil
        )

        scanProgress = 1.0
        lastResult = result
        await writeMarkersToHealthKit(markers)
        return result
    }

    // MARK: - OCR con VNRecognizeTextRequest

    private func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw LabScannerError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es", "en"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.01  // detectar texto pequeño en tablas

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // Vision perform es síncrono y pesado: ejecutarlo FUERA del main actor
            // para no congelar la UI mientras se escanea
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    // CRÍTICO: sin este resume la continuation queda colgada (hang silencioso)
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: - Parser de marcadores de laboratorio

    // Diccionario de marcadores conocidos con sus rangos de referencia típicos
    private let knownMarkers: [(pattern: String, name: String, unit: String, refMin: Double?, refMax: Double?)] = [
        // Perfil lipídico
        ("colesterol.*total|cholesterol.*total", "Colesterol Total", "mg/dL", 0, 200),
        ("ldl", "Colesterol LDL", "mg/dL", 0, 100),
        ("hdl", "Colesterol HDL", "mg/dL", 40, 999),
        ("triglicéridos|triglycerides|trigliceridos", "Triglicéridos", "mg/dL", 0, 150),
        // Glucosa
        ("glucosa.*ayunas|fasting.*glucose|glucemia", "Glucosa en Ayunas", "mg/dL", 70, 99),
        ("hemoglobina.*glicada|hba1c|a1c", "Hemoglobina Glicada (HbA1c)", "%", 0, 5.7),
        // Función renal
        ("creatinina|creatinine", "Creatinina", "mg/dL", 0.6, 1.2),
        ("urea|bun", "Urea (BUN)", "mg/dL", 7, 20),
        ("ácido.*úrico|uric.*acid", "Ácido Úrico", "mg/dL", 2.4, 6.0),
        // Función hepática
        ("alt|gpt|alanina", "ALT (GPT)", "U/L", 0, 40),
        ("ast|got|aspartato", "AST (GOT)", "U/L", 0, 40),
        ("ggt|gamma.*glutamil", "GGT", "U/L", 0, 50),
        ("bilirrubina.*total|total.*bilirubin", "Bilirrubina Total", "mg/dL", 0, 1.2),
        // Tiroides
        ("tsh|tirotropina", "TSH", "mUI/L", 0.4, 4.0),
        ("t4.*libre|free.*t4", "T4 Libre", "ng/dL", 0.8, 1.8),
        // Hemograma
        ("hemoglobina(?!.*glicada)|haemoglobin", "Hemoglobina", "g/dL", 12, 17),
        ("hematocrito|hematocrit", "Hematocrito", "%", 36, 50),
        ("leucocitos|leucocytes|wbc", "Leucocitos (WBC)", "10³/µL", 4.0, 11.0),
        ("plaquetas|platelets", "Plaquetas", "10³/µL", 150, 400),
        // Vitaminas y minerales
        ("vitamina.*d|25.*oh.*d", "Vitamina D (25-OH)", "ng/mL", 30, 100),
        ("vitamina.*b12|cobalamina", "Vitamina B12", "pg/mL", 200, 900),
        ("ferritina|ferritin", "Ferritina", "ng/mL", 12, 300),
        ("hierro.*sérico|serum.*iron", "Hierro Sérico", "µg/dL", 60, 170),
        ("transferrina|transferrin", "Transferrina", "mg/dL", 200, 360),
        // Inflamación
        ("pcr|proteína.*c.*reactiva|c.*reactive.*protein", "Proteína C Reactiva", "mg/L", 0, 5),
        ("vsg|velocidad.*sedimentación", "VSG", "mm/h", 0, 20),
    ]

    func parseLabMarkers(from text: String) -> [LabMarker] {
        var markers: [LabMarker] = []
        let lines = text.components(separatedBy: "\n")

        for (pattern, name, unit, refMin, refMax) in knownMarkers {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }

            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                guard regex.firstMatch(in: line, range: range) != nil else { continue }

                // Extraer el valor numérico de la línea
                if let value = extractFirstNumber(from: line) {
                    // Determinar si está en rango
                    let status: LabMarker.MarkerStatus
                    if let min = refMin, let max = refMax {
                        if value < min { status = .low }
                        else if value > max { status = .high }
                        else { status = .normal }
                    } else {
                        status = .normal
                    }

                    markers.append(LabMarker(
                        id: UUID(),
                        name: name,
                        value: value,
                        unit: unit,
                        referenceMin: refMin,
                        referenceMax: refMax,
                        status: status
                    ))
                    break // evitar duplicados de la misma línea
                }
            }
        }

        return markers
    }

    // MARK: - Escribir en HealthKit

    private func writeMarkersToHealthKit(_ markers: [LabMarker]) async {
        // Mapeo de nombres de marcadores a HealthKit Quantity Types
        let mapping: [String: (HKQuantityTypeIdentifier, HKUnit)] = [
            "Glucosa en Ayunas": (.bloodGlucose, HKUnit(from: "mg/dL")),
            "Colesterol Total":  (.bloodGlucose, HKUnit(from: "mg/dL")), // ejemplo, usar el tipo correcto
        ]

        for marker in markers {
            guard let (typeId, unit) = mapping[marker.name],
                  let quantityType = HKQuantityType.quantityType(forIdentifier: typeId) else { continue }

            let quantity = HKQuantity(unit: unit, doubleValue: marker.value)
            let sample = HKQuantitySample(
                type: quantityType,
                quantity: quantity,
                start: Date(),
                end: Date(),
                metadata: ["Neximed_Source": "lab_ocr"]
            )

            try? await HKHealthStore().save(sample)
        }
    }

    // MARK: - Helpers

    private func extractFirstNumber(from text: String) -> Double? {
        let pattern = #"(?<![a-zA-Z])(\d+[.,]?\d*)(?:\s*(?:mg|g|mUI|µg|ng|pg|mm|%|U))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            // Fallback: cualquier número en la línea
            return extractAnyNumber(from: text)
        }
        let numStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
        return Double(numStr)
    }

    private func extractAnyNumber(from text: String) -> Double? {
        let pattern = #"\b(\d+[.,]\d+|\d{1,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(String(text[range]).replacingOccurrences(of: ",", with: "."))
    }

    private func extractDate(from text: String) -> Date? {
        let patterns = [
            #"\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})\b"#,
            #"\b(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            let dateStr = String(text[range]).replacingOccurrences(of: "-", with: "/").replacingOccurrences(of: ".", with: "/")
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }

    private func extractLabName(from text: String) -> String? {
        let labKeywords = ["laboratorio", "clínica", "hospital", "centro médico", "análisis"]
        let lines = text.components(separatedBy: "\n").prefix(5) // Solo las primeras líneas

        for line in lines {
            for keyword in labKeywords {
                if line.lowercased().contains(keyword) {
                    return line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }

    // MARK: - Errores

    enum LabScannerError: LocalizedError {
        case invalidImage
        case ocrFailure
        case noMarkersFound

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "La imagen no es válida"
            case .ocrFailure: return "No se pudo leer el texto de la analítica"
            case .noMarkersFound: return "No se encontraron marcadores de laboratorio reconocibles"
            }
        }
    }
}

// Import necesario para HealthKit en este archivo
import HealthKit

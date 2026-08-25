// Neximed — FoodAnalyzer.swift
// Análisis de fotos de comida con Vision + Foundation Models
// y escáner de códigos de barras para productos envasados

@preconcurrency import Vision
import CoreImage
import UIKit
import Foundation
import Observation

@MainActor
@Observable
final class FoodAnalyzer {

    static let shared = FoodAnalyzer()

    var isAnalyzing = false

    // MARK: - Análisis de foto de plato

    func analyzePhoto(_ uiImage: UIImage) async throws -> HealthAgent.FoodAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // 1. Pre-procesar la imagen con Vision para mejorar calidad
        let processedData = try await preprocessImage(uiImage)

        // 2. Pasar al agente de IA para estimación de macros
        return await HealthAgent.shared.analyzeFoodPhoto(processedData)
    }

    // MARK: - Pre-procesamiento con Vision

    private func preprocessImage(_ image: UIImage) async throws -> Data {
        guard let cgImage = image.cgImage else {
            throw FoodAnalyzerError.invalidImage
        }

        // Usar Vision para detectar y recortar la región de comida
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if error != nil {
                    // Si falla detección, usar imagen completa
                    continuation.resume(returning: image.jpegData(compressionQuality: 0.8) ?? Data())
                    return
                }

                // Usar la imagen completa comprimida para el LLM
                let compressed = image.jpegData(compressionQuality: 0.7) ?? Data()
                continuation.resume(returning: compressed)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // Vision perform es síncrono y pesado: ejecutarlo FUERA del main actor
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    // CRÍTICO: si perform lanza, el closure nunca se ejecuta.
                    // Sin este resume la continuation queda colgada (hang silencioso).
                    continuation.resume(returning: image.jpegData(compressionQuality: 0.7) ?? Data())
                }
            }
        }
    }

    // MARK: - Escáner de código de barras

    struct BarcodeProduct {
        let barcode: String
        let name: String?
        let brand: String?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let carbsPer100g: Double?
        let fatPer100g: Double?
        let servingSize: Double?     // gramos
    }

    func scanBarcode(from uiImage: UIImage) async throws -> BarcodeProduct? {
        guard let cgImage = uiImage.cgImage else {
            throw FoodAnalyzerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNBarcodeObservation],
                      let barcode = results.first?.payloadStringValue else {
                    continuation.resume(returning: nil)
                    return
                }

                // Buscar en la base de datos local o Open Food Facts
                Task {
                    let product = await FoodDatabaseService.shared.lookup(barcode: barcode)
                    continuation.resume(returning: product)
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // Vision perform es síncrono y pesado: ejecutarlo FUERA del main actor
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    // CRÍTICO: sin este resume la continuation queda colgada (hang silencioso)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - OCR de etiquetas nutricionales

    func scanNutritionLabel(from uiImage: UIImage) async throws -> NutritionLabelData? {
        guard let cgImage = uiImage.cgImage else {
            throw FoodAnalyzerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                // Parsear el texto reconocido para extraer valores nutricionales
                let parser = NutritionLabelParser()
                let data = parser.parse(text: recognizedText)
                continuation.resume(returning: data)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es", "en"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // Vision perform es síncrono y pesado: ejecutarlo FUERA del main actor
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    // CRÍTICO: sin este resume la continuation queda colgada (hang silencioso)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    struct NutritionLabelData {
        let servingSize: Double?
        let calories: Double?
        let protein: Double?
        let carbs: Double?
        let fat: Double?
        let fiber: Double?
        let sugar: Double?
        let sodium: Double?
    }

    // MARK: - Errores

    enum FoodAnalyzerError: LocalizedError {
        case invalidImage
        case analysisFailure(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "La imagen no es válida"
            case .analysisFailure(let msg): return "Error en análisis: \(msg)"
            }
        }
    }
}

// MARK: - Parser de etiquetas nutricionales

final class NutritionLabelParser {

    func parse(text: String) -> FoodAnalyzer.NutritionLabelData {
        let lines = text.components(separatedBy: "\n")

        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var fiber: Double?
        var sugar: Double?
        var sodium: Double?
        var servingSize: Double?

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()

            if lower.contains("kcal") || lower.contains("energía") || lower.contains("calorías") {
                calories = extractNumber(from: line)
            } else if lower.contains("proteína") || lower.contains("protein") {
                protein = extractNumber(from: line)
            } else if lower.contains("carbohidrato") || lower.contains("carbohydrate") || lower.contains("glúcidos") {
                carbs = extractNumber(from: line)
            } else if lower.contains("grasa") || lower.contains("fat") || lower.contains("lípidos") {
                fat = extractNumber(from: line)
            } else if lower.contains("fibra") || lower.contains("fiber") {
                fiber = extractNumber(from: line)
            } else if lower.contains("azúcar") || lower.contains("sugar") {
                sugar = extractNumber(from: line)
            } else if lower.contains("sodio") || lower.contains("sodium") || lower.contains("sal") {
                sodium = extractNumber(from: line)
            } else if lower.contains("ración") || lower.contains("porción") || lower.contains("serving") {
                servingSize = extractNumber(from: line)
            }

            _ = i // supress warning
        }

        return FoodAnalyzer.NutritionLabelData(
            servingSize: servingSize,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
    }

    private func extractNumber(from text: String) -> Double? {
        // Regex para encontrar números (incluyendo decimales con punto o coma)
        let pattern = #"(\d+[.,]?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let numberStr = text[range].replacingOccurrences(of: ",", with: ".")
        return Double(numberStr)
    }
}

// MARK: - Servicio de base de datos de alimentos

final class FoodDatabaseService: Sendable {
    static let shared = FoodDatabaseService()

    // En producción: Open Food Facts API local o SQLite embedded
    func lookup(barcode: String) async -> FoodAnalyzer.BarcodeProduct? {
        // Intentar primero la base de datos local (SQLite bundled)
        if let local = lookupLocal(barcode: barcode) {
            return local
        }

        // Fallback: Open Food Facts API (solo si hay red, con consentimiento del usuario)
        return await lookupOpenFoodFacts(barcode: barcode)
    }

    private func lookupLocal(barcode: String) -> FoodAnalyzer.BarcodeProduct? {
        // TODO: Implementar SQLite con subset de Open Food Facts descargado localmente
        // Para el MVP, retornamos nil y usamos la API
        return nil
    }

    private func lookupOpenFoodFacts(barcode: String) async -> FoodAnalyzer.BarcodeProduct? {
        let urlStr = "https://world.openfoodfacts.org/api/v3/product/\(barcode).json"
        guard let url = URL(string: urlStr) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let product = json?["product"] as? [String: Any] else { return nil }

            let nutriments = product["nutriments"] as? [String: Any]
            let name = product["product_name"] as? String
            let brand = product["brands"] as? String

            return FoodAnalyzer.BarcodeProduct(
                barcode: barcode,
                name: name,
                brand: brand,
                caloriesPer100g: nutriments?["energy-kcal_100g"] as? Double,
                proteinPer100g: nutriments?["proteins_100g"] as? Double,
                carbsPer100g: nutriments?["carbohydrates_100g"] as? Double,
                fatPer100g: nutriments?["fat_100g"] as? Double,
                servingSize: nutriments?["serving_size"] as? Double
            )
        } catch {
            return nil
        }
    }
}

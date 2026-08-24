// Neximed — MedicalReportExporter.swift
// Generador integral del Dossier Clínico en PDF estructurado para consulta médica

import PDFKit
import UIKit
import SwiftUI

@MainActor
final class MedicalReportExporter {

    static let shared = MedicalReportExporter()

    struct FullClinicalReportData {
        let patientProfile: UserProfile
        let periodDescription: String
        let generatedDate: Date
        let activityAverage: (steps: Int, calories: Int)
        let cardioSummary: (restingHR: Double?, hrv: Double?)
        let sleepAverageHours: Double
        let activeMedications: [MedicationEntry]
        let recentSymptoms: [SymptomEntry]
        let recentLabMarkers: [LabMarker]
        let keyObservations: [String]
        let questionsForDoctor: [String]
    }

    // MARK: - Generación del PDF Clínico Completo

    func generatePDF(data: FullClinicalReportData) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Neximed - Asistente Clínico Personal",
            kCGPDFContextAuthor: data.patientProfile.name,
            kCGPDFContextTitle: "Dossier Clínico para Consulta Médica"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        // Formato estándar A4 (595.2 x 841.8 puntos)
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = 30
            let margin: CGFloat = 32
            let contentWidth = pageWidth - (margin * 2)

            // 1. Cabecera con Datos del Paciente, Alergias y Ficha Base
            currentY = drawPatientHeader(startY: currentY, margin: margin, width: contentWidth, data: data)
            currentY += 8

            drawLine(from: CGPoint(x: margin, y: currentY), to: CGPoint(x: pageWidth - margin, y: currentY))
            currentY += 12

            // 2. Constantes y Descanso (Apple Watch)
            currentY = drawCardioAndSleepSection(startY: currentY, margin: margin, width: contentWidth, data: data)
            currentY += 14

            // 3. Botiquín Activo: Medicación y Suplementos
            currentY = drawMedicationsSection(startY: currentY, margin: margin, width: contentWidth, medications: data.activeMedications)
            currentY += 14

            // 4. Registro de Síntomas Recientes (Últimas 4 semanas)
            if !data.recentSymptoms.isEmpty {
                currentY = drawSymptomsSection(startY: currentY, margin: margin, width: contentWidth, symptoms: data.recentSymptoms)
                currentY += 14
            }

            // 5. Analíticas de Laboratorio Recientes
            if !data.recentLabMarkers.isEmpty {
                currentY = drawLabsSection(startY: currentY, margin: margin, width: contentWidth, markers: data.recentLabMarkers)
                currentY += 14
            }

            // 6. Observaciones Objetivas y Preguntas para el Médico
            currentY = drawObservationsAndQuestionsSection(startY: currentY, margin: margin, width: contentWidth, data: data)

            // 7. Pie de página legal
            drawFooter(pageRect: pageRect, margin: margin)
        }
    }

    // MARK: - Subrutinas de Renderizado

    private func drawPatientHeader(startY: CGFloat, margin: CGFloat, width: CGFloat, data: FullClinicalReportData) -> CGFloat {
        var y = startY
        let profile = data.patientProfile

        let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 13), .foregroundColor: UIColor.black]
        let subAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray]
        let tagTitleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: UIColor.darkGray]
        let tagValAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.black]
        let alertAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.red]

        "DOSSIER DE SALUD Y PREPARACIÓN DE CONSULTA — NEXIMED".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
        y += 16

        let allergiesText = profile.allergies.isEmpty ? "Ninguna declarada" : profile.allergies.joined(separator: ", ")
        let foodAllergensText = profile.foodAllergens.isEmpty ? "Ninguno declarado" : profile.foodAllergens.map(\.rawValue).joined(separator: ", ")
        let chronicText = profile.chronicConditions.isEmpty ? "Ninguna" : profile.chronicConditions.joined(separator: ", ")
        let bloodText = profile.bloodType ?? "No especificado"

        "Paciente: \(profile.name) | Período: \(data.periodDescription) | Emitido: \(data.generatedDate.formatted(date: .abbreviated, time: .omitted))".draw(at: CGPoint(x: margin, y: y), withAttributes: subAttr)
        y += 14

        // Fila de etiquetas clínicas rápidas
        "G. Sanguíneo: ".draw(at: CGPoint(x: margin, y: y), withAttributes: tagTitleAttr)
        bloodText.draw(at: CGPoint(x: margin + 60, y: y), withAttributes: tagValAttr)

        "Alergias: ".draw(at: CGPoint(x: margin + 140, y: y), withAttributes: tagTitleAttr)
        allergiesText.draw(at: CGPoint(x: margin + 180, y: y), withAttributes: profile.allergies.isEmpty ? tagValAttr : alertAttr)

        // Alergias alimentarias (los 14 de la UE) — destacadas en rojo si existen
        "Alerg. aliment.: ".draw(at: CGPoint(x: margin + 8, y: y + 12), withAttributes: tagTitleAttr)
        foodAllergensText.draw(at: CGPoint(x: margin + 95, y: y + 12), withAttributes: profile.foodAllergens.isEmpty ? tagValAttr : alertAttr)

        "Antecedentes: ".draw(at: CGPoint(x: margin + 330, y: y), withAttributes: tagTitleAttr)
        chronicText.draw(at: CGPoint(x: margin + 395, y: y), withAttributes: tagValAttr)

        return y + 12
    }

    private func drawCardioAndSleepSection(startY: CGFloat, margin: CGFloat, width: CGFloat, data: FullClinicalReportData) -> CGFloat {
        var y = startY
        drawSectionTitle("1. CONSTANTES Y DESCANSO (Apple Watch - Medias de Período)", atY: y, margin: margin)
        y += 14

        let boxHeight: CGFloat = 38
        let boxWidth: CGFloat = (width - 24) / 3

        let boxes = [
            ("FC en Reposo Media", String(format: "%.0f bpm", data.cardioSummary.restingHR ?? 0), "Rango estable"),
            ("Variabilidad (HRV)", String(format: "%.0f ms", data.cardioSummary.hrv ?? 0), "Tono vagal basal"),
            ("Sueño Promedio", String(format: "%.1f h/noche", data.sleepAverageHours), "Medias de descanso")
        ]

        for (i, box) in boxes.enumerated() {
            let x = margin + CGFloat(i) * (boxWidth + 12)
            let rect = CGRect(x: x, y: y, width: boxWidth, height: boxHeight)
            drawStatBox(rect: rect, title: box.0, value: box.1, subtitle: box.2)
        }

        return y + boxHeight
    }

    private func drawMedicationsSection(startY: CGFloat, margin: CGFloat, width: CGFloat, medications: [MedicationEntry]) -> CGFloat {
        var y = startY
        drawSectionTitle("2. BOTIQUÍN ACTIVO (Medicación y Suplementos Declarados)", atY: y, margin: margin)
        y += 14

        if medications.isEmpty {
            let emptyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 8), .foregroundColor: UIColor.gray]
            "No hay medicación ni suplementación activa registrada.".draw(at: CGPoint(x: margin + 8, y: y), withAttributes: emptyAttr)
            return y + 12
        }

        let medAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.black]
        let boldAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.black]

        for med in medications.prefix(4) {
            let bullet = "• \(med.name)"
            let details = "— Dosis: \(med.dosage) | Frecuencia: \(med.frequency) (\(med.type.rawValue))"
            bullet.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: boldAttr)
            details.draw(at: CGPoint(x: margin + 120, y: y), withAttributes: medAttr)
            y += 11
        }

        return y
    }

    private func drawSymptomsSection(startY: CGFloat, margin: CGFloat, width: CGFloat, symptoms: [SymptomEntry]) -> CGFloat {
        var y = startY
        drawSectionTitle("3. SÍNTOMAS REGISTRADOS RECIENTEMENTE (Últimas 4 semanas)", atY: y, margin: margin)
        y += 14

        let font = UIFont.systemFont(ofSize: 8)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]

        for sym in symptoms.prefix(3) {
            let dateStr = sym.timestamp.formatted(date: .numeric, time: .omitted)
            let trigger = sym.contextTrigger != nil ? " (\(sym.contextTrigger!))" : ""
            let line = "• [\(dateStr)] \(sym.symptomName) - Intensidad: \(sym.intensity.rawValue)\(trigger)"
            line.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: attr)
            y += 11
        }

        return y
    }

    private func drawLabsSection(startY: CGFloat, margin: CGFloat, width: CGFloat, markers: [LabMarker]) -> CGFloat {
        var y = startY
        drawSectionTitle("4. ANALÍTICAS DE LABORATORIO RECIENTES", atY: y, margin: margin)
        y += 14

        let colX = [margin + 8, margin + 170, margin + 270, margin + 380]
        let headerAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: UIColor.darkGray]

        "Parámetro".draw(at: CGPoint(x: colX[0], y: y), withAttributes: headerAttr)
        "Resultado".draw(at: CGPoint(x: colX[1], y: y), withAttributes: headerAttr)
        "Rango Lab".draw(at: CGPoint(x: colX[2], y: y), withAttributes: headerAttr)
        "Estado".draw(at: CGPoint(x: colX[3], y: y), withAttributes: headerAttr)
        y += 12

        let rowAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.black]

        for marker in markers.prefix(5) {
            let statusText = marker.isInRange ? "En rango" : "Fuera de rango"
            let statusColor: UIColor = marker.isInRange ? .darkGray : .red
            let statusAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: statusColor]

            marker.name.draw(at: CGPoint(x: colX[0], y: y), withAttributes: rowAttr)
            "\(marker.value, specifier: "%.1f") \(marker.unit)".draw(at: CGPoint(x: colX[1], y: y), withAttributes: rowAttr)
            "\(marker.referenceMin ?? 0) - \(marker.referenceMax ?? 0) \(marker.unit)".draw(at: CGPoint(x: colX[2], y: y), withAttributes: rowAttr)
            statusText.draw(at: CGPoint(x: colX[3], y: y), withAttributes: statusAttr)
            y += 10
        }

        return y
    }

    private func drawObservationsAndQuestionsSection(startY: CGFloat, margin: CGFloat, width: CGFloat, data: FullClinicalReportData) -> CGFloat {
        var y = startY
        drawSectionTitle("5. OBSERVACIONES OBJETIVAS Y PREGUNTAS PREPARADAS PARA LA CONSULTA", atY: y, margin: margin)
        y += 14

        let bodyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.black]
        let boldAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.black]

        "Observaciones de datos notables:".draw(at: CGPoint(x: margin + 8, y: y), withAttributes: boldAttr)
        y += 11

        for obs in data.keyObservations.prefix(2) {
            "• \(obs)".draw(at: CGPoint(x: margin + 14, y: y), withAttributes: bodyAttr)
            y += 10
        }

        y += 4
        "Preguntas formuladas por el paciente para esta visita médica:".draw(at: CGPoint(x: margin + 8, y: y), withAttributes: boldAttr)
        y += 11

        for q in data.questionsForDoctor.prefix(3) {
            "• \(q)".draw(at: CGPoint(x: margin + 14, y: y), withAttributes: bodyAttr)
            y += 10
        }

        return y
    }

    private func drawStatBox(rect: CGRect, title: String, value: String, subtitle: String) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setFillColor(UIColor(white: 0.96, alpha: 1.0).cgColor)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        context.addPath(path.cgPath)
        context.fillPath()
        context.restoreGState()

        let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray]
        let valAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black]
        let subAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: UIColor.darkGray]

        title.draw(at: CGPoint(x: rect.origin.x + 6, y: rect.origin.y + 4), withAttributes: titleAttr)
        value.draw(at: CGPoint(x: rect.origin.x + 6, y: rect.origin.y + 14), withAttributes: valAttr)
        subtitle.draw(at: CGPoint(x: rect.origin.x + 6, y: rect.origin.y + 26), withAttributes: subAttr)
    }

    private func drawSectionTitle(_ title: String, atY y: CGFloat, margin: CGFloat) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: UIColor(red: 0.08, green: 0.18, blue: 0.45, alpha: 1.0)
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attr)
    }

    private func drawLine(from start: CGPoint, to end: CGPoint) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.6)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private func drawFooter(pageRect: CGRect, margin: CGFloat) {
        let footerText = "DOCUMENTO INFORMATIVO GENERADO POR NEXIMED. NO CONSTITUYE DIAGNÓSTICO MÉDICO. DATOS BAJO CONTROL DEL PACIENTE."
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6.0),
            .foregroundColor: UIColor.gray
        ]
        footerText.draw(at: CGPoint(x: margin, y: pageRect.height - 20), withAttributes: attr)
    }
}

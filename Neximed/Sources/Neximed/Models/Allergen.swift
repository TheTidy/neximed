// Neximed — Allergen.swift
// Alergenos alimentarios reconocidos — basado en los 14 obligatorios de la
// UE (Reglamento 1169/2011) más intolerancias comunes.

import Foundation

enum Allergen: String, CaseIterable, Identifiable, Codable, Sendable {
    // 14 alergenos obligatorios de la UE
    case gluten = "Gluten"
    case crustaceans = "Crustáceos"
    case eggs = "Huevos"
    case fish = "Pescado"
    case peanuts = "Cacahuetes"
    case soy = "Soja"
    case milk = "Lácteos"
    case treeNuts = "Frutos de cáscara"
    case celery = "Apio"
    case mustard = "Mostaza"
    case sesame = "Sésamo"
    case sulfites = "Sulfitos"
    case lupin = "Altramuces"
    case molluscs = "Moluscos"

    // Intolerancias y sensibilidades comunes (no alergias IgE, pero relevantes)
    case lactose = "Lactosa (intolerancia)"
    case histamine = "Histamina"
    case sulfiteSensitivity = "Sensibilidad a sulfitos"

    var id: String { rawValue }

    var isEURequired: Bool {
        Self.euRequired.contains(self)
    }

    /// Los 14 alergenos obligatorios de la UE (Reglamento 1169/2011)
    static let euRequired: [Allergen] = [
        .gluten, .crustaceans, .eggs, .fish, .peanuts, .soy, .milk,
        .treeNuts, .celery, .mustard, .sesame, .sulfites, .lupin, .molluscs
    ]

    /// Icono SF Symbol para la UI
    var icon: String {
        switch self {
        case .gluten:      return "wheat"
        case .crustaceans: return "ladybug.fill"
        case .eggs:        return "circle.circle"
        case .fish:        return "fish.fill"
        case .peanuts:     return "leaf.fill"
        case .soy:         return "seal.fill"
        case .milk:        return "drop.fill"
        case .treeNuts:    return "nuts"
        case .celery:      return "carrot.fill"
        case .mustard:     return "drop.triangle"
        case .sesame:      return "sparkles"
        case .sulfites:    return "exclamationmark.triangle.fill"
        case .lupin:       return "leaf"
        case .molluscs:    return "shell.fill"
        case .lactose:     return "drop.circle"
        case .histamine:   return "waveform.path"
        case .sulfiteSensitivity: return "exclamationmark.circle.fill"
        }
    }
}
// Neximed — FoodDatabase.swift
// Base de datos curada de alimentos on-device (sin red) para el registro
// manual de comidas. Cada entrada: macros por 100g + porción típica.
//
// ALERGENOS: cada alimento se etiqueta según los 14 alergenos obligatorios
// de la UE + lactosa. Verificar siempre la etiqueta en productos procesados.

import Foundation

struct FoodItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let brand: String?          // nil para genéricos
    let category: Category
    let kcalPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double
    let sugarPer100g: Double
    let sodiumPer100g: Double
    let typicalServingGrams: Double

    /// Alergenos presentes (etiquetado automático por el creador del alimento)
    let allergens: [Allergen]

    enum Category: String, CaseIterable, Sendable {
        case fruit = "Frutas"
        case vegetable = "Verduras"
        case protein = "Proteínas"
        case dairy = "Lácteos"
        case grain = "Cereales y pan"
        case legumes = "Legumbres"
        case nuts = "Frutos secos"
        case prepared = "Platos preparados"
        case beverage = "Bebidas"
        case other = "Otros"
    }

    /// true si el alimento contiene gluten (el alergeno más común)
    var containsGluten: Bool { allergens.contains(.gluten) }

    /// true si es apto para dieta vegana
    var isVegan: Bool { !allergens.contains(.milk) && !allergens.contains(.eggs) && !allergens.contains(.fish) && !allergens.contains(.crustaceans) && !allergens.contains(.molluscs) }

    /// true si es apto para dieta vegetariana
    var isVegetarian: Bool { !allergens.contains(.fish) && !allergens.contains(.crustaceans) && !allergens.contains(.molluscs) }

    /// Macros por porción típica
    var kcalPerServing: Double { kcalPer100g * typicalServingGrams / 100 }
    var proteinPerServing: Double { proteinPer100g * typicalServingGrams / 100 }
    var carbsPerServing: Double { carbsPer100g * typicalServingGrams / 100 }
    var fatPerServing: Double { fatPer100g * typicalServingGrams / 100 }
    var fiberPerServing: Double { fiberPer100g * typicalServingGrams / 100 }
    var sugarPerServing: Double { sugarPer100g * typicalServingGrams / 100 }
    var sodiumPerServing: Double { sodiumPer100g * typicalServingGrams / 100 }
}

struct FoodDatabase {

    static let shared = FoodDatabase()

    /// Búsqueda case-insensitive por nombre (y marca)
    func search(_ query: String, limit: Int = 30) -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return Array(allItems.prefix(limit)) }

        let normalized = normalize(trimmed)
        return allItems
            .filter {
                normalize($0.name.lowercased()).contains(normalized) ||
                ($0.brand?.lowercased().contains(trimmed) ?? false)
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Alergenos del alimento que coinciden con los del usuario
    func unsafeAllergens(for item: FoodItem, userAllergens: Set<Allergen>) -> [Allergen] {
        item.allergens.filter { userAllergens.contains($0) }
    }

    /// Filtra alimentos según dieta (vegana/vegetariana) si el usuario lo pide
    func search(_ query: String, diet: String?, limit: Int = 30) -> [FoodItem] {
        let base = search(query, limit: limit)
        guard let diet else { return base }
        switch diet.lowercased() {
        case "vegana":       return base.filter { $0.isVegan }
        case "vegetariana":  return base.filter { $0.isVegetarian }
        default:              return base
        }
    }

    /// Elimina acentos para búsqueda robusta
    private func normalize(_ s: String) -> String {
        let map: [Character: Character] = [
            "á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u",
            "à": "a", "è": "e", "ì": "i", "ò": "o", "ù": "u",
            "ü": "u", "ñ": "n"
        ]
        return s.map { map[$0] ?? $0 }.map { String($0) }.joined()
    }

    // MARK: - Base curada (por 100g; porciones típicas orientativas)

    private let allItems: [FoodItem] = [
        FoodItem(name: "Manzana", brand: nil, category: .fruit, kcalPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, fiberPer100g: 2.4, sugarPer100g: 10, sodiumPer100g: 1, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Plátano", brand: nil, category: .fruit, kcalPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, fiberPer100g: 2.6, sugarPer100g: 12, sodiumPer100g: 1, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Naranja", brand: nil, category: .fruit, kcalPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, fiberPer100g: 2.4, sugarPer100g: 9, sodiumPer100g: 0, typicalServingGrams: 130, allergens: []),
        FoodItem(name: "Fresas", brand: nil, category: .fruit, kcalPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 8, fatPer100g: 0.3, fiberPer100g: 2, sugarPer100g: 4.9, sodiumPer100g: 1, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Uvas", brand: nil, category: .fruit, kcalPer100g: 69, proteinPer100g: 0.7, carbsPer100g: 18, fatPer100g: 0.2, fiberPer100g: 0.9, sugarPer100g: 16, sodiumPer100g: 2, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Pera", brand: nil, category: .fruit, kcalPer100g: 57, proteinPer100g: 0.4, carbsPer100g: 15, fatPer100g: 0.1, fiberPer100g: 3.1, sugarPer100g: 10, sodiumPer100g: 1, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Kiwi", brand: nil, category: .fruit, kcalPer100g: 61, proteinPer100g: 1.1, carbsPer100g: 15, fatPer100g: 0.5, fiberPer100g: 3, sugarPer100g: 9, sodiumPer100g: 3, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Mango", brand: nil, category: .fruit, kcalPer100g: 60, proteinPer100g: 0.8, carbsPer100g: 15, fatPer100g: 0.4, fiberPer100g: 1.6, sugarPer100g: 14, sodiumPer100g: 1, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Piña", brand: nil, category: .fruit, kcalPer100g: 50, proteinPer100g: 0.5, carbsPer100g: 13, fatPer100g: 0.1, fiberPer100g: 1.4, sugarPer100g: 10, sodiumPer100g: 1, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Sandía", brand: nil, category: .fruit, kcalPer100g: 30, proteinPer100g: 0.6, carbsPer100g: 8, fatPer100g: 0.2, fiberPer100g: 0.4, sugarPer100g: 6, sodiumPer100g: 1, typicalServingGrams: 200, allergens: []),
        FoodItem(name: "Melón", brand: nil, category: .fruit, kcalPer100g: 34, proteinPer100g: 0.8, carbsPer100g: 8, fatPer100g: 0.2, fiberPer100g: 0.9, sugarPer100g: 8, sodiumPer100g: 16, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Arándanos", brand: nil, category: .fruit, kcalPer100g: 57, proteinPer100g: 0.7, carbsPer100g: 14, fatPer100g: 0.3, fiberPer100g: 2.4, sugarPer100g: 10, sodiumPer100g: 1, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Cerezas", brand: nil, category: .fruit, kcalPer100g: 63, proteinPer100g: 1.1, carbsPer100g: 16, fatPer100g: 0.2, fiberPer100g: 2.1, sugarPer100g: 13, sodiumPer100g: 0, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Melocotón", brand: nil, category: .fruit, kcalPer100g: 39, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.3, fiberPer100g: 1.5, sugarPer100g: 8, sodiumPer100g: 0, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Aguacate", brand: nil, category: .fruit, kcalPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, fiberPer100g: 7, sugarPer100g: 0.7, sodiumPer100g: 7, typicalServingGrams: 50, allergens: []),
        FoodItem(name: "Limón", brand: nil, category: .fruit, kcalPer100g: 29, proteinPer100g: 1.1, carbsPer100g: 9, fatPer100g: 0.3, fiberPer100g: 2.8, sugarPer100g: 2.5, sodiumPer100g: 2, typicalServingGrams: 50, allergens: []),
        FoodItem(name: "Mandarina", brand: nil, category: .fruit, kcalPer100g: 53, proteinPer100g: 0.8, carbsPer100g: 13, fatPer100g: 0.3, fiberPer100g: 1.8, sugarPer100g: 11, sodiumPer100g: 2, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Granada", brand: nil, category: .fruit, kcalPer100g: 83, proteinPer100g: 1.7, carbsPer100g: 19, fatPer100g: 1.2, fiberPer100g: 4, sugarPer100g: 14, sodiumPer100g: 3, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Ciruela", brand: nil, category: .fruit, kcalPer100g: 46, proteinPer100g: 0.7, carbsPer100g: 11, fatPer100g: 0.3, fiberPer100g: 1.4, sugarPer100g: 10, sodiumPer100g: 0, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Higos", brand: nil, category: .fruit, kcalPer100g: 74, proteinPer100g: 0.8, carbsPer100g: 19, fatPer100g: 0.3, fiberPer100g: 2.9, sugarPer100g: 16, sodiumPer100g: 1, typicalServingGrams: 60, allergens: []),
        FoodItem(name: "Tomate", brand: nil, category: .vegetable, kcalPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, fiberPer100g: 1.2, sugarPer100g: 2.6, sodiumPer100g: 5, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Brócoli", brand: nil, category: .vegetable, kcalPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7, fatPer100g: 0.4, fiberPer100g: 2.6, sugarPer100g: 1.7, sodiumPer100g: 33, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Espinacas", brand: nil, category: .vegetable, kcalPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4, fiberPer100g: 2.2, sugarPer100g: 0.4, sodiumPer100g: 79, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Zanahoria", brand: nil, category: .vegetable, kcalPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.2, fiberPer100g: 2.8, sugarPer100g: 4.7, sodiumPer100g: 69, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Lechuga", brand: nil, category: .vegetable, kcalPer100g: 15, proteinPer100g: 1.4, carbsPer100g: 2.9, fatPer100g: 0.2, fiberPer100g: 1.3, sugarPer100g: 0.8, sodiumPer100g: 28, typicalServingGrams: 60, allergens: []),
        FoodItem(name: "Calabacín", brand: nil, category: .vegetable, kcalPer100g: 17, proteinPer100g: 1.2, carbsPer100g: 3.1, fatPer100g: 0.3, fiberPer100g: 1, sugarPer100g: 2.5, sodiumPer100g: 8, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Apio", brand: nil, category: .vegetable, kcalPer100g: 16, proteinPer100g: 0.7, carbsPer100g: 3, fatPer100g: 0.2, fiberPer100g: 1.6, sugarPer100g: 1.3, sodiumPer100g: 80, typicalServingGrams: 80, allergens: [.celery]),
        FoodItem(name: "Pepino", brand: nil, category: .vegetable, kcalPer100g: 15, proteinPer100g: 0.7, carbsPer100g: 3.6, fatPer100g: 0.1, fiberPer100g: 0.5, sugarPer100g: 1.7, sodiumPer100g: 2, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Pimiento rojo", brand: nil, category: .vegetable, kcalPer100g: 31, proteinPer100g: 1, carbsPer100g: 6, fatPer100g: 0.3, fiberPer100g: 2.1, sugarPer100g: 4.2, sodiumPer100g: 4, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Cebolla", brand: nil, category: .vegetable, kcalPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9, fatPer100g: 0.1, fiberPer100g: 1.7, sugarPer100g: 4.2, sodiumPer100g: 4, typicalServingGrams: 50, allergens: []),
        FoodItem(name: "Ajo", brand: nil, category: .vegetable, kcalPer100g: 149, proteinPer100g: 6.4, carbsPer100g: 33, fatPer100g: 0.5, fiberPer100g: 2.1, sugarPer100g: 1, sodiumPer100g: 17, typicalServingGrams: 10, allergens: []),
        FoodItem(name: "Champiñones", brand: nil, category: .vegetable, kcalPer100g: 22, proteinPer100g: 3.1, carbsPer100g: 3.3, fatPer100g: 0.3, fiberPer100g: 1, sugarPer100g: 2, sodiumPer100g: 5, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Berenjena", brand: nil, category: .vegetable, kcalPer100g: 25, proteinPer100g: 1, carbsPer100g: 6, fatPer100g: 0.2, fiberPer100g: 3, sugarPer100g: 3.5, sodiumPer100g: 2, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Coliflor", brand: nil, category: .vegetable, kcalPer100g: 25, proteinPer100g: 1.9, carbsPer100g: 5, fatPer100g: 0.3, fiberPer100g: 2, sugarPer100g: 1.9, sodiumPer100g: 30, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Espárragos", brand: nil, category: .vegetable, kcalPer100g: 20, proteinPer100g: 2.2, carbsPer100g: 4, fatPer100g: 0.1, fiberPer100g: 2.1, sugarPer100g: 1.9, sodiumPer100g: 2, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Remolacha", brand: nil, category: .vegetable, kcalPer100g: 43, proteinPer100g: 1.6, carbsPer100g: 10, fatPer100g: 0.2, fiberPer100g: 2.8, sugarPer100g: 7, sodiumPer100g: 78, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Calabaza", brand: nil, category: .vegetable, kcalPer100g: 26, proteinPer100g: 1, carbsPer100g: 7, fatPer100g: 0.1, fiberPer100g: 0.5, sugarPer100g: 2.8, sodiumPer100g: 1, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Guisantes", brand: nil, category: .vegetable, kcalPer100g: 81, proteinPer100g: 5.4, carbsPer100g: 14, fatPer100g: 0.4, fiberPer100g: 5.7, sugarPer100g: 5.7, sodiumPer100g: 3, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Maíz dulce", brand: nil, category: .vegetable, kcalPer100g: 86, proteinPer100g: 3.3, carbsPer100g: 19, fatPer100g: 1.4, fiberPer100g: 2.7, sugarPer100g: 3.2, sodiumPer100g: 3, typicalServingGrams: 80, allergens: []),
        FoodItem(name: "Rábano", brand: nil, category: .vegetable, kcalPer100g: 16, proteinPer100g: 0.7, carbsPer100g: 3.4, fatPer100g: 0.1, fiberPer100g: 1.6, sugarPer100g: 1.9, sodiumPer100g: 39, typicalServingGrams: 50, allergens: []),
        FoodItem(name: "Alcachofa", brand: nil, category: .vegetable, kcalPer100g: 47, proteinPer100g: 3.3, carbsPer100g: 11, fatPer100g: 0.2, fiberPer100g: 5.4, sugarPer100g: 1, sodiumPer100g: 94, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Pollo (pechuga)", brand: nil, category: .protein, kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 74, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Salmón", brand: nil, category: .protein, kcalPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 59, typicalServingGrams: 120, allergens: [.fish]),
        FoodItem(name: "Atún (lata al natural)", brand: nil, category: .protein, kcalPer100g: 116, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 1, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 247, typicalServingGrams: 80, allergens: [.fish]),
        FoodItem(name: "Huevo", brand: nil, category: .protein, kcalPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, fiberPer100g: 0, sugarPer100g: 1.1, sodiumPer100g: 124, typicalServingGrams: 55, allergens: [.eggs]),
        FoodItem(name: "Carne magra de ternera", brand: nil, category: .protein, kcalPer100g: 217, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 12, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 60, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Tofu", brand: nil, category: .protein, kcalPer100g: 76, proteinPer100g: 8, carbsPer100g: 1.9, fatPer100g: 4.8, fiberPer100g: 0.3, sugarPer100g: 0.6, sodiumPer100g: 7, typicalServingGrams: 100, allergens: [.soy]),
        FoodItem(name: "Pavo (pechuga)", brand: nil, category: .protein, kcalPer100g: 135, proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 1, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 65, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Cerdo magro", brand: nil, category: .protein, kcalPer100g: 242, proteinPer100g: 27, carbsPer100g: 0, fatPer100g: 14, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 62, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Cordero", brand: nil, category: .protein, kcalPer100g: 294, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 21, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 72, typicalServingGrams: 120, allergens: []),
        FoodItem(name: "Bacalao", brand: nil, category: .protein, kcalPer100g: 82, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 0.7, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 54, typicalServingGrams: 120, allergens: [.fish]),
        FoodItem(name: "Merluza", brand: nil, category: .protein, kcalPer100g: 90, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 1.3, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 86, typicalServingGrams: 120, allergens: [.fish]),
        FoodItem(name: "Gambas", brand: nil, category: .protein, kcalPer100g: 99, proteinPer100g: 24, carbsPer100g: 0.2, fatPer100g: 0.3, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 111, typicalServingGrams: 80, allergens: [.crustaceans]),
        FoodItem(name: "Mejillones", brand: nil, category: .protein, kcalPer100g: 86, proteinPer100g: 12, carbsPer100g: 4, fatPer100g: 2.2, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 286, typicalServingGrams: 80, allergens: [.molluscs]),
        FoodItem(name: "Sardinas en aceite", brand: nil, category: .protein, kcalPer100g: 208, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 11, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 414, typicalServingGrams: 60, allergens: [.fish]),
        FoodItem(name: "Jamón serrano", brand: nil, category: .protein, kcalPer100g: 250, proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 14, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 1100, typicalServingGrams: 30, allergens: []),
        FoodItem(name: "Jamón de pavo", brand: nil, category: .protein, kcalPer100g: 90, proteinPer100g: 16, carbsPer100g: 1, fatPer100g: 2, fiberPer100g: 0, sugarPer100g: 1, sodiumPer100g: 800, typicalServingGrams: 50, allergens: []),
        FoodItem(name: "Salchichas", brand: nil, category: .protein, kcalPer100g: 301, proteinPer100g: 12, carbsPer100g: 3, fatPer100g: 27, fiberPer100g: 0, sugarPer100g: 1, sodiumPer100g: 798, typicalServingGrams: 50, allergens: [.gluten, .soy]),
        FoodItem(name: "Pulpo", brand: nil, category: .protein, kcalPer100g: 82, proteinPer100g: 15, carbsPer100g: 2, fatPer100g: 1, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 230, typicalServingGrams: 100, allergens: [.molluscs]),
        FoodItem(name: "Lomo embuchado", brand: nil, category: .protein, kcalPer100g: 243, proteinPer100g: 24, carbsPer100g: 1, fatPer100g: 15, fiberPer100g: 0, sugarPer100g: 1, sodiumPer100g: 980, typicalServingGrams: 30, allergens: []),
        FoodItem(name: "Leche entera", brand: nil, category: .dairy, kcalPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3, fiberPer100g: 0, sugarPer100g: 5.1, sodiumPer100g: 49, typicalServingGrams: 200, allergens: [.milk, .lactose]),
        FoodItem(name: "Leche semidesnatada", brand: nil, category: .dairy, kcalPer100g: 46, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 1.5, fiberPer100g: 0, sugarPer100g: 4.8, sodiumPer100g: 50, typicalServingGrams: 200, allergens: [.milk, .lactose]),
        FoodItem(name: "Leche desnatada", brand: nil, category: .dairy, kcalPer100g: 34, proteinPer100g: 3.4, carbsPer100g: 5, fatPer100g: 0.1, fiberPer100g: 0, sugarPer100g: 5, sodiumPer100g: 52, typicalServingGrams: 200, allergens: [.milk, .lactose]),
        FoodItem(name: "Yogur natural", brand: nil, category: .dairy, kcalPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3, fiberPer100g: 0, sugarPer100g: 4.7, sodiumPer100g: 46, typicalServingGrams: 125, allergens: [.milk, .lactose]),
        FoodItem(name: "Yogur griego", brand: nil, category: .dairy, kcalPer100g: 97, proteinPer100g: 9, carbsPer100g: 4, fatPer100g: 5, fiberPer100g: 0, sugarPer100g: 4, sodiumPer100g: 35, typicalServingGrams: 125, allergens: [.milk, .lactose]),
        FoodItem(name: "Queso fresco", brand: nil, category: .dairy, kcalPer100g: 98, proteinPer100g: 11, carbsPer100g: 3.4, fatPer100g: 4.3, fiberPer100g: 0, sugarPer100g: 3.4, sodiumPer100g: 364, typicalServingGrams: 50, allergens: [.milk, .lactose]),
        FoodItem(name: "Queso curado", brand: nil, category: .dairy, kcalPer100g: 402, proteinPer100g: 25, carbsPer100g: 1.3, fatPer100g: 33, fiberPer100g: 0, sugarPer100g: 0.5, sodiumPer100g: 621, typicalServingGrams: 30, allergens: [.milk, .lactose]),
        FoodItem(name: "Queso mozzarella", brand: nil, category: .dairy, kcalPer100g: 280, proteinPer100g: 28, carbsPer100g: 3.1, fatPer100g: 17, fiberPer100g: 0, sugarPer100g: 1, sodiumPer100g: 373, typicalServingGrams: 50, allergens: [.milk, .lactose]),
        FoodItem(name: "Requesón", brand: nil, category: .dairy, kcalPer100g: 98, proteinPer100g: 11, carbsPer100g: 3.4, fatPer100g: 4.3, fiberPer100g: 0, sugarPer100g: 3.4, sodiumPer100g: 364, typicalServingGrams: 50, allergens: [.milk, .lactose]),
        FoodItem(name: "Mantequilla", brand: nil, category: .dairy, kcalPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.1, fatPer100g: 81, fiberPer100g: 0, sugarPer100g: 0.1, sodiumPer100g: 643, typicalServingGrams: 10, allergens: [.milk, .lactose]),
        FoodItem(name: "Kéfir", brand: nil, category: .dairy, kcalPer100g: 64, proteinPer100g: 3.3, carbsPer100g: 5, fatPer100g: 3.6, fiberPer100g: 0, sugarPer100g: 4, sodiumPer100g: 40, typicalServingGrams: 200, allergens: [.milk, .lactose]),
        FoodItem(name: "Queso parmesano", brand: nil, category: .dairy, kcalPer100g: 431, proteinPer100g: 38, carbsPer100g: 4.1, fatPer100g: 29, fiberPer100g: 0, sugarPer100g: 0.8, sodiumPer100g: 1529, typicalServingGrams: 20, allergens: [.milk, .lactose]),
        FoodItem(name: "Pan integral", brand: nil, category: .grain, kcalPer100g: 247, proteinPer100g: 13, carbsPer100g: 41, fatPer100g: 3.4, fiberPer100g: 7, sugarPer100g: 4, sodiumPer100g: 540, typicalServingGrams: 40, allergens: [.gluten]),
        FoodItem(name: "Pan blanco", brand: nil, category: .grain, kcalPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3.2, fiberPer100g: 2.7, sugarPer100g: 5, sodiumPer100g: 491, typicalServingGrams: 40, allergens: [.gluten]),
        FoodItem(name: "Arroz blanco cocido", brand: nil, category: .grain, kcalPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, fiberPer100g: 0.4, sugarPer100g: 0.1, sodiumPer100g: 1, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Avena", brand: nil, category: .grain, kcalPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, fiberPer100g: 10, sugarPer100g: 1, sodiumPer100g: 2, typicalServingGrams: 40, allergens: [.gluten]),
        FoodItem(name: "Pasta cocida", brand: nil, category: .grain, kcalPer100g: 131, proteinPer100g: 5, carbsPer100g: 25, fatPer100g: 1.1, fiberPer100g: 1.8, sugarPer100g: 0.6, sodiumPer100g: 6, typicalServingGrams: 150, allergens: [.gluten]),
        FoodItem(name: "Patata cocida", brand: nil, category: .grain, kcalPer100g: 87, proteinPer100g: 1.9, carbsPer100g: 20, fatPer100g: 0.1, fiberPer100g: 1.8, sugarPer100g: 0.8, sodiumPer100g: 5, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Cuscús", brand: nil, category: .grain, kcalPer100g: 112, proteinPer100g: 3.8, carbsPer100g: 23, fatPer100g: 0.2, fiberPer100g: 1.4, sugarPer100g: 0.1, sodiumPer100g: 5, typicalServingGrams: 150, allergens: [.gluten]),
        FoodItem(name: "Quinoa cocida", brand: nil, category: .grain, kcalPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 21, fatPer100g: 1.9, fiberPer100g: 2.8, sugarPer100g: 0.9, sodiumPer100g: 7, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Copos de maíz", brand: nil, category: .grain, kcalPer100g: 357, proteinPer100g: 8, carbsPer100g: 84, fatPer100g: 0.9, fiberPer100g: 3, sugarPer100g: 10, sodiumPer100g: 730, typicalServingGrams: 30, allergens: [.gluten]),
        FoodItem(name: "Muesli", brand: nil, category: .grain, kcalPer100g: 390, proteinPer100g: 10, carbsPer100g: 65, fatPer100g: 8, fiberPer100g: 8, sugarPer100g: 18, sodiumPer100g: 20, typicalServingGrams: 50, allergens: [.gluten, .treeNuts]),
        FoodItem(name: "Galletas integrales", brand: nil, category: .grain, kcalPer100g: 450, proteinPer100g: 8, carbsPer100g: 65, fatPer100g: 18, fiberPer100g: 5, sugarPer100g: 20, sodiumPer100g: 400, typicalServingGrams: 25, allergens: [.gluten, .milk, .lactose]),
        FoodItem(name: "Biscotes", brand: nil, category: .grain, kcalPer100g: 378, proteinPer100g: 12, carbsPer100g: 74, fatPer100g: 5, fiberPer100g: 4, sugarPer100g: 4, sodiumPer100g: 600, typicalServingGrams: 20, allergens: [.gluten]),
        FoodItem(name: "Tortilla de maíz", brand: nil, category: .grain, kcalPer100g: 218, proteinPer100g: 6, carbsPer100g: 46, fatPer100g: 4, fiberPer100g: 6, sugarPer100g: 2, sodiumPer100g: 200, typicalServingGrams: 30, allergens: [.gluten]),
        FoodItem(name: "Pan de centeno", brand: nil, category: .grain, kcalPer100g: 259, proteinPer100g: 9, carbsPer100g: 48, fatPer100g: 3.3, fiberPer100g: 5.8, sugarPer100g: 3, sodiumPer100g: 570, typicalServingGrams: 40, allergens: [.gluten]),
        FoodItem(name: "Croissant", brand: nil, category: .grain, kcalPer100g: 406, proteinPer100g: 8, carbsPer100g: 46, fatPer100g: 21, fiberPer100g: 2.6, sugarPer100g: 11, sodiumPer100g: 384, typicalServingGrams: 50, allergens: [.gluten, .milk, .lactose, .eggs]),
        FoodItem(name: "Pan de molde", brand: nil, category: .grain, kcalPer100g: 265, proteinPer100g: 8.9, carbsPer100g: 48, fatPer100g: 3.6, fiberPer100g: 2.5, sugarPer100g: 5, sodiumPer100g: 490, typicalServingGrams: 30, allergens: [.gluten]),
        FoodItem(name: "Pan de pita", brand: nil, category: .grain, kcalPer100g: 275, proteinPer100g: 9, carbsPer100g: 55, fatPer100g: 1.2, fiberPer100g: 2.2, sugarPer100g: 1, sodiumPer100g: 536, typicalServingGrams: 50, allergens: [.gluten]),
        FoodItem(name: "Bulgur cocido", brand: nil, category: .grain, kcalPer100g: 83, proteinPer100g: 3.1, carbsPer100g: 18.6, fatPer100g: 0.2, fiberPer100g: 4.5, sugarPer100g: 0.1, sodiumPer100g: 5, typicalServingGrams: 150, allergens: [.gluten]),
        FoodItem(name: "Boniato", brand: nil, category: .grain, kcalPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1, fiberPer100g: 3, sugarPer100g: 4.2, sodiumPer100g: 55, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Yuca cocida", brand: nil, category: .grain, kcalPer100g: 160, proteinPer100g: 1.4, carbsPer100g: 38, fatPer100g: 0.3, fiberPer100g: 1.8, sugarPer100g: 1.7, sodiumPer100g: 15, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Lentejas cocidas", brand: nil, category: .legumes, kcalPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, fiberPer100g: 7.9, sugarPer100g: 1.8, sodiumPer100g: 2, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Garbanzos cocidos", brand: nil, category: .legumes, kcalPer100g: 164, proteinPer100g: 8.9, carbsPer100g: 27, fatPer100g: 2.6, fiberPer100g: 7.6, sugarPer100g: 4.8, sodiumPer100g: 7, typicalServingGrams: 150, allergens: [.sesame]),
        FoodItem(name: "Alubias cocidas", brand: nil, category: .legumes, kcalPer100g: 127, proteinPer100g: 8.7, carbsPer100g: 22.8, fatPer100g: 0.5, fiberPer100g: 6.4, sugarPer100g: 0.3, sodiumPer100g: 5, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Judías verdes", brand: nil, category: .legumes, kcalPer100g: 31, proteinPer100g: 1.8, carbsPer100g: 7, fatPer100g: 0.2, fiberPer100g: 3.4, sugarPer100g: 3.3, sodiumPer100g: 6, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Habas cocidas", brand: nil, category: .legumes, kcalPer100g: 62, proteinPer100g: 4.8, carbsPer100g: 10, fatPer100g: 0.4, fiberPer100g: 3.6, sugarPer100g: 1, sodiumPer100g: 2, typicalServingGrams: 100, allergens: []),
        FoodItem(name: "Lentejas rojas cocidas", brand: nil, category: .legumes, kcalPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, fiberPer100g: 7.9, sugarPer100g: 1.8, sodiumPer100g: 2, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Tempeh", brand: nil, category: .legumes, kcalPer100g: 193, proteinPer100g: 19, carbsPer100g: 8, fatPer100g: 11, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 9, typicalServingGrams: 100, allergens: [.soy]),
        FoodItem(name: "Hummus", brand: nil, category: .legumes, kcalPer100g: 166, proteinPer100g: 7.9, carbsPer100g: 14, fatPer100g: 9.6, fiberPer100g: 6, sugarPer100g: 0.3, sodiumPer100g: 379, typicalServingGrams: 30, allergens: [.sesame]),
        FoodItem(name: "Soja cocida", brand: nil, category: .legumes, kcalPer100g: 173, proteinPer100g: 17, carbsPer100g: 9.9, fatPer100g: 9, fiberPer100g: 6, sugarPer100g: 3, sodiumPer100g: 1, typicalServingGrams: 100, allergens: [.soy]),
        FoodItem(name: "Almendras", brand: nil, category: .nuts, kcalPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 50, fiberPer100g: 12.5, sugarPer100g: 4.4, sodiumPer100g: 1, typicalServingGrams: 30, allergens: [.treeNuts]),
        FoodItem(name: "Nueces", brand: nil, category: .nuts, kcalPer100g: 654, proteinPer100g: 15, carbsPer100g: 14, fatPer100g: 65, fiberPer100g: 6.7, sugarPer100g: 2.6, sodiumPer100g: 2, typicalServingGrams: 30, allergens: [.treeNuts]),
        FoodItem(name: "Cacahuetes", brand: nil, category: .nuts, kcalPer100g: 567, proteinPer100g: 26, carbsPer100g: 16, fatPer100g: 49, fiberPer100g: 8.5, sugarPer100g: 4, sodiumPer100g: 18, typicalServingGrams: 30, allergens: [.peanuts]),
        FoodItem(name: "Anacardos", brand: nil, category: .nuts, kcalPer100g: 553, proteinPer100g: 18, carbsPer100g: 30, fatPer100g: 44, fiberPer100g: 3.3, sugarPer100g: 5.9, sodiumPer100g: 12, typicalServingGrams: 30, allergens: [.treeNuts]),
        FoodItem(name: "Pistachos", brand: nil, category: .nuts, kcalPer100g: 560, proteinPer100g: 20, carbsPer100g: 28, fatPer100g: 45, fiberPer100g: 10, sugarPer100g: 7.7, sodiumPer100g: 1, typicalServingGrams: 30, allergens: [.treeNuts]),
        FoodItem(name: "Avellanas", brand: nil, category: .nuts, kcalPer100g: 628, proteinPer100g: 15, carbsPer100g: 17, fatPer100g: 61, fiberPer100g: 9.7, sugarPer100g: 4.3, sodiumPer100g: 0, typicalServingGrams: 30, allergens: [.treeNuts]),
        FoodItem(name: "Pipas de girasol", brand: nil, category: .nuts, kcalPer100g: 584, proteinPer100g: 21, carbsPer100g: 20, fatPer100g: 51, fiberPer100g: 8.6, sugarPer100g: 2.6, sodiumPer100g: 9, typicalServingGrams: 30, allergens: []),
        FoodItem(name: "Sésamo", brand: nil, category: .nuts, kcalPer100g: 573, proteinPer100g: 18, carbsPer100g: 23, fatPer100g: 50, fiberPer100g: 11.8, sugarPer100g: 0.3, sodiumPer100g: 11, typicalServingGrams: 15, allergens: [.sesame]),
        FoodItem(name: "Castañas", brand: nil, category: .nuts, kcalPer100g: 213, proteinPer100g: 2.4, carbsPer100g: 45, fatPer100g: 2.3, fiberPer100g: 8.1, sugarPer100g: 11, sodiumPer100g: 3, typicalServingGrams: 50, allergens: [.treeNuts]),
        FoodItem(name: "Coco rallado", brand: nil, category: .nuts, kcalPer100g: 660, proteinPer100g: 6.9, carbsPer100g: 24, fatPer100g: 65, fiberPer100g: 16, sugarPer100g: 7, sodiumPer100g: 20, typicalServingGrams: 15, allergens: [.treeNuts]),
        FoodItem(name: "Macadamia", brand: nil, category: .nuts, kcalPer100g: 718, proteinPer100g: 7.9, carbsPer100g: 14, fatPer100g: 76, fiberPer100g: 8.6, sugarPer100g: 4.6, sodiumPer100g: 5, typicalServingGrams: 20, allergens: [.treeNuts]),
        FoodItem(name: "Tortilla española", brand: nil, category: .prepared, kcalPer100g: 186, proteinPer100g: 6.3, carbsPer100g: 12, fatPer100g: 12, fiberPer100g: 1.5, sugarPer100g: 1, sodiumPer100g: 400, typicalServingGrams: 150, allergens: [.eggs]),
        FoodItem(name: "Paella", brand: nil, category: .prepared, kcalPer100g: 135, proteinPer100g: 8, carbsPer100g: 18, fatPer100g: 3.5, fiberPer100g: 1, sugarPer100g: 0.5, sodiumPer100g: 380, typicalServingGrams: 250, allergens: [.crustaceans, .molluscs, .fish]),
        FoodItem(name: "Gazpacho", brand: nil, category: .prepared, kcalPer100g: 38, proteinPer100g: 1, carbsPer100g: 7, fatPer100g: 0.8, fiberPer100g: 1.5, sugarPer100g: 4, sodiumPer100g: 250, typicalServingGrams: 200, allergens: [.celery]),
        FoodItem(name: "Sopa de verduras", brand: nil, category: .prepared, kcalPer100g: 35, proteinPer100g: 1.5, carbsPer100g: 6, fatPer100g: 0.5, fiberPer100g: 1.5, sugarPer100g: 2, sodiumPer100g: 450, typicalServingGrams: 250, allergens: []),
        FoodItem(name: "Pizza margarita", brand: nil, category: .prepared, kcalPer100g: 266, proteinPer100g: 11, carbsPer100g: 33, fatPer100g: 10, fiberPer100g: 2.3, sugarPer100g: 3.5, sodiumPer100g: 540, typicalServingGrams: 125, allergens: [.gluten, .milk, .lactose]),
        FoodItem(name: "Hamburguesa de ternera", brand: nil, category: .prepared, kcalPer100g: 295, proteinPer100g: 17, carbsPer100g: 24, fatPer100g: 14, fiberPer100g: 1.5, sugarPer100g: 4, sodiumPer100g: 480, typicalServingGrams: 150, allergens: [.gluten]),
        FoodItem(name: "Ensalada mixta", brand: nil, category: .prepared, kcalPer100g: 85, proteinPer100g: 4, carbsPer100g: 8, fatPer100g: 4, fiberPer100g: 2.5, sugarPer100g: 3, sodiumPer100g: 180, typicalServingGrams: 200, allergens: []),
        FoodItem(name: "Garbanzos con espinacas", brand: nil, category: .prepared, kcalPer100g: 130, proteinPer100g: 7, carbsPer100g: 18, fatPer100g: 3.5, fiberPer100g: 7, sugarPer100g: 2, sodiumPer100g: 350, typicalServingGrams: 200, allergens: [.sesame]),
        FoodItem(name: "Lentejas estofadas", brand: nil, category: .prepared, kcalPer100g: 140, proteinPer100g: 8, carbsPer100g: 20, fatPer100g: 3, fiberPer100g: 8, sugarPer100g: 2, sodiumPer100g: 380, typicalServingGrams: 200, allergens: []),
        FoodItem(name: "Pollo al curry", brand: nil, category: .prepared, kcalPer100g: 160, proteinPer100g: 18, carbsPer100g: 8, fatPer100g: 6, fiberPer100g: 2, sugarPer100g: 2, sodiumPer100g: 420, typicalServingGrams: 200, allergens: []),
        FoodItem(name: "Falafel", brand: nil, category: .prepared, kcalPer100g: 333, proteinPer100g: 13, carbsPer100g: 32, fatPer100g: 18, fiberPer100g: 5, sugarPer100g: 4, sodiumPer100g: 300, typicalServingGrams: 80, allergens: [.gluten, .sesame]),
        FoodItem(name: "Hamburguesa vegana", brand: nil, category: .prepared, kcalPer100g: 240, proteinPer100g: 20, carbsPer100g: 15, fatPer100g: 11, fiberPer100g: 4, sugarPer100g: 2, sodiumPer100g: 450, typicalServingGrams: 100, allergens: [.gluten, .soy]),
        FoodItem(name: "Agua", brand: nil, category: .beverage, kcalPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 0, typicalServingGrams: 250, allergens: []),
        FoodItem(name: "Café solo", brand: nil, category: .beverage, kcalPer100g: 2, proteinPer100g: 0.1, carbsPer100g: 0, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 2, typicalServingGrams: 150, allergens: []),
        FoodItem(name: "Té sin azúcar", brand: nil, category: .beverage, kcalPer100g: 1, proteinPer100g: 0, carbsPer100g: 0.3, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 1, typicalServingGrams: 200, allergens: []),
        FoodItem(name: "Zumo de naranja natural", brand: nil, category: .beverage, kcalPer100g: 45, proteinPer100g: 0.7, carbsPer100g: 10, fatPer100g: 0.2, fiberPer100g: 0.2, sugarPer100g: 8, sodiumPer100g: 1, typicalServingGrams: 200, allergens: []),
        FoodItem(name: "Refresco de cola", brand: nil, category: .beverage, kcalPer100g: 42, proteinPer100g: 0, carbsPer100g: 11, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 11, sodiumPer100g: 4, typicalServingGrams: 330, allergens: []),
        FoodItem(name: "Cerveza", brand: nil, category: .beverage, kcalPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 3.6, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 4, typicalServingGrams: 330, allergens: [.gluten]),
        FoodItem(name: "Vino tinto", brand: nil, category: .beverage, kcalPer100g: 85, proteinPer100g: 0.1, carbsPer100g: 2.6, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 0.6, sodiumPer100g: 5, typicalServingGrams: 150, allergens: [.sulfites]),
        FoodItem(name: "Leche de almendras", brand: nil, category: .beverage, kcalPer100g: 24, proteinPer100g: 0.6, carbsPer100g: 2.6, fatPer100g: 1.3, fiberPer100g: 0.4, sugarPer100g: 2.6, sodiumPer100g: 63, typicalServingGrams: 200, allergens: [.treeNuts]),
        FoodItem(name: "Leche de soja", brand: nil, category: .beverage, kcalPer100g: 33, proteinPer100g: 3.3, carbsPer100g: 1.7, fatPer100g: 1.8, fiberPer100g: 0.6, sugarPer100g: 1, sodiumPer100g: 51, typicalServingGrams: 200, allergens: [.soy]),
        FoodItem(name: "Batido de proteína", brand: nil, category: .beverage, kcalPer100g: 60, proteinPer100g: 12, carbsPer100g: 2, fatPer100g: 1, fiberPer100g: 0, sugarPer100g: 1, sodiumPer100g: 100, typicalServingGrams: 250, allergens: [.milk, .lactose]),
        FoodItem(name: "Kombucha", brand: nil, category: .beverage, kcalPer100g: 18, proteinPer100g: 0, carbsPer100g: 4, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 3, sodiumPer100g: 4, typicalServingGrams: 250, allergens: []),
        FoodItem(name: "Horchata", brand: nil, category: .beverage, kcalPer100g: 90, proteinPer100g: 1, carbsPer100g: 16, fatPer100g: 2.5, fiberPer100g: 0.5, sugarPer100g: 10, sodiumPer100g: 10, typicalServingGrams: 200, allergens: [.treeNuts]),
        FoodItem(name: "Agua con gas", brand: nil, category: .beverage, kcalPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, fiberPer100g: 0, sugarPer100g: 0, sodiumPer100g: 10, typicalServingGrams: 250, allergens: [])
    ];
}
// Neximed — FoodLogView.swift
// Registro manual de comidas usando la base de datos curada on-device.

import SwiftUI
import SwiftData

struct FoodLogView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onLog: (String, Double, Double, Double, Double) -> Void  // nombre, kcal, prot, carbos, grasa

    @Query private var profiles: [UserProfile]
    var profile: UserProfile? { profiles.first }

    @State private var searchText = ""
    @State private var results: [FoodItem] = [];
    @State private var pendingItem: FoodItem?
    @State private var showAllergenAlert = false

    /// Alergenos del usuario (para mostrar alertas)
    private var userAllergens: Set<Allergen> {
        Set(profile?.foodAllergens ?? [])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Buscador
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.msTextTertiary)
                    TextField("Buscar alimento (manzana, pollo, arroz...)", text: $searchText)
                        .font(.msBody)
                        .foregroundStyle(.msTextPrimary)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.msTextTertiary)
                        }
                    }
                }
                .padding(12)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Resultados
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { item in
                            foodRow(item)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.msBackground)
            .navigationTitle("Añadir comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            results = FoodDatabase.shared.search(searchText)
        }
        .onChange(of: searchText) { _, newValue in
            results = FoodDatabase.shared.search(newValue)
        }
        // ALERTA DE ALERGENOS: confirmación antes de registrar un alimento peligroso
        .alert("Alergeno detectado", isPresented: $showAllergenAlert, presenting: pendingItem) { item in
            Button("Registrar de todos modos", role: .destructive) {
                logItem(item)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { item in
            let allergens = FoodDatabase.shared.unsafeAllergens(for: item, userAllergens: userAllergens)
                .map(\.rawValue)
                .joined(separator: ", ")
            Text("Este alimento contiene \(allergens), que has marcado como alergeno en tu perfil.")
        }
    }

    private func foodRow(_ item: FoodItem) -> some View {
        // Detectar alergenos del usuario en este alimento
        let unsafeAllergens = FoodDatabase.shared.unsafeAllergens(for: item, userAllergens: userAllergens)

        return Button {
            // Confirmar antes de registrar si hay alergenos
            if !unsafeAllergens.isEmpty {
                pendingItem = item
                showAllergenAlert = true
            } else {
                logItem(item)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msTextPrimary)
                    Text("\(item.category.rawValue) · \(Int(item.typicalServingGrams)) g por porción")
                        .font(.system(size: 10))
                        .foregroundStyle(.msTextTertiary)

                    // Aviso de alergeno si aplica
                    if !unsafeAllergens.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "allergens")
                                .font(.system(size: 9))
                            Text("Contiene: \(unsafeAllergens.map(\.rawValue).joined(separator: ", "))")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.msDanger)
                        .padding(.top, 2)
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.kcalPerServing)) kcal")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msAccent)
                    Text("P \(Int(item.proteinPerServing)) · C \(Int(item.carbsPerServing)) · G \(Int(item.fatPerServing))")
                        .font(.system(size: 10))
                        .foregroundStyle(.msTextTertiary)
                }
            }
            .padding(12)
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(unsafeAllergens.isEmpty ? Color.clear : Color.msDanger.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Registra el alimento (sin alergenos o tras confirmación)
    private func logItem(_ item: FoodItem) {
        onLog(
            item.name,
            item.kcalPerServing,
            item.proteinPerServing,
            item.carbsPerServing,
            item.fatPerServing
        )
        dismiss()
    }
}
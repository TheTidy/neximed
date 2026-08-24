// Neximed — DailyCheckInView.swift
// Check-in diario de bienestar: ánimo, energía y calidad de sueño en 1 tap.

import SwiftUI
import SwiftData

struct DailyCheckInView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mood: DailyCheckIn.MoodLevel = .neutral
    @State private var energy: DailyCheckIn.EnergyLevel = .medium
    @State private var sleepQuality = 3
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Ánimo
                    VStack(alignment: .leading, spacing: 10) {
                        Text("¿Cómo te sientes hoy?")
                            .font(.msHeadline)
                            .foregroundStyle(.msTextPrimary)

                        HStack(spacing: 10) {
                            ForEach(DailyCheckIn.MoodLevel.allCases, id: \.self) { level in
                                moodButton(level)
                            }
                        }
                    }

                    // Energía
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nivel de energía")
                            .font(.msHeadline)
                            .foregroundStyle(.msTextPrimary)

                        HStack(spacing: 10) {
                            ForEach(DailyCheckIn.EnergyLevel.allCases, id: \.self) { level in
                                energyButton(level)
                            }
                        }
                    }

                    // Calidad de sueño
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Calidad de tu sueño anoche")
                            .font(.msHeadline)
                            .foregroundStyle(.msTextPrimary)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.msSpring) { sleepQuality = star }
                                } label: {
                                    Image(systemName: star <= sleepQuality ? "star.fill" : "star")
                                        .font(.system(size: 28))
                                        .foregroundStyle(star <= sleepQuality ? Color.msSleep : Color.msTextTertiary)
                                }
                            }
                        }
                    }

                    // Notas opcionales
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Algo que quieras recordar (opcional)")
                            .font(.msHeadline)
                            .foregroundStyle(.msTextPrimary)
                        TextEditor(text: $notes)
                            .font(.msBody)
                            .foregroundStyle(.msTextPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(height: 90)
                            .background(Color.msSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Guardar
                    Button(action: save) {
                        Text("Guardar check-in")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient.msAgentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Spacer(minLength: 30)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Color.msBackground)
            .navigationTitle("Check-in diario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Botones

    private func moodButton(_ level: DailyCheckIn.MoodLevel) -> some View {
        Button {
            withAnimation(.msSpring) { mood = level }
        } label: {
            VStack(spacing: 4) {
                Text(level.emoji)
                    .font(.system(size: 32))
                Text(level.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(mood == level ? Color.msAccent : Color.msTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(mood == level ? Color.msAccent.opacity(0.15) : Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(mood == level ? Color.msAccent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func energyButton(_ level: DailyCheckIn.EnergyLevel) -> some View {
        Button {
            withAnimation(.msSpring) { energy = level }
        } label: {
            VStack(spacing: 4) {
                Text(level.emoji)
                    .font(.system(size: 32))
                Text(level.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(energy == level ? Color.msNutrition : Color.msTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(energy == level ? Color.msNutrition.opacity(0.15) : Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(energy == level ? Color.msNutrition : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Guardar

    private func save() {
        let checkIn = DailyCheckIn(
            mood: mood,
            energyLevel: energy,
            sleepQuality: sleepQuality,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(checkIn)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    DailyCheckInView()
        .modelContainer(for: [DailyCheckIn.self], inMemory: true)
        .preferredColorScheme(.dark)
}
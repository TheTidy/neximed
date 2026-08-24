// Neximed — WeightTrackingView.swift
// Registro y tendencia de peso corporal con gráfica Swift Charts.

import SwiftUI
import SwiftData
import Charts

struct WeightTrackingView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .forward) private var weights: [WeightEntry]

    @State private var newWeight = ""
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(.msAccent)
                Text("Seguimiento de peso")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()

                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.msAccent)
                }
            }

            if weights.count >= 2 {
                Chart(weights, id: \.id) { w in
                    LineMark(
                        x: .value("Fecha", w.date),
                        y: .value("Peso", w.weightKg)
                    )
                    .foregroundStyle(Color.msAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                    PointMark(
                        x: .value("Fecha", w.date),
                        y: .value("Peso", w.weightKg)
                    )
                    .foregroundStyle(Color.msAccent)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.day().month())
                            .foregroundStyle(Color.msTextTertiary)
                    }
                }
                .frame(height: 140)
            } else {
                Text("Registra al menos 2 pesos para ver tu tendencia.")
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
                    .padding(.vertical, 20)
            }

            // Último registro
            if let last = weights.last {
                HStack(spacing: 12) {
                    Text(String(format: "%.1f", last.weightKg))
                        .font(.msMetric)
                        .foregroundStyle(.msTextPrimary)
                    Text("kg · \(last.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .glassCard()
        .sheet(isPresented: $showAddSheet) {
            AddWeightSheet { kg in
                modelContext.insert(WeightEntry(weightKg: kg))
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Hoja de registro de peso

struct AddWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Double) -> Void

    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Peso en kg", text: $weightText)
                    .font(.msDisplayMedium)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .background(Color.msSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 32)

                Button {
                    if let kg = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
                        onSave(kg)
                        dismiss()
                    }
                } label: {
                    Text("Guardar")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.msAgentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .disabled(weightText.isEmpty)

                Spacer()
            }
            .padding(.top, 40)
            .background(Color.msBackground)
            .navigationTitle("Registrar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
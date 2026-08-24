// Neximed — CorrelationsView.swift
// Muestra las correlaciones observacionales calculadas con los datos del usuario.

import SwiftUI

struct CorrelationsView: View {

    let results: [CorrelationResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(.msAccent)
                Text("Patrones en tus datos")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            if results.isEmpty {
                Text("Necesitas más datos para encontrar patrones. Sigue registrando durante unos días.")
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
            } else {
                ForEach(results) { result in
                    correlationRow(result)
                }
            }

            Text("Patrones observacionales de tus propios datos — no implican causa ni diagnóstico.")
                .font(.system(size: 9.5))
                .foregroundStyle(.msTextTertiary)
        }
        .padding(16)
        .glassCard()
    }

    private func correlationRow(_ result: CorrelationResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: strengthIcon(result.strength))
                .foregroundStyle(strengthColor(result.strength))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
                Text(result.description)
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
                Text(result.strength.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(strengthColor(result.strength))
            }
            Spacer()
        }
        .padding(10)
        .background(Color.msSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func strengthIcon(_ s: CorrelationResult.Strength) -> String {
        switch s {
        case .strong:   return "arrow.up.arrow.down.circle.fill"
        case .moderate: return "arrow.up.arrow.down.circle"
        case .weak:     return "minus.circle"
        case .none:     return "circle.dashed"
        }
    }

    private func strengthColor(_ s: CorrelationResult.Strength) -> Color {
        switch s {
        case .strong:   return .msAccent
        case .moderate: return .msLabs
        case .weak:     return .msTextSecondary
        case .none:     return .msTextTertiary
        }
    }
}
// Neximed — RecommendationsView.swift
// Muestra las recomendaciones de estilo de vida generadas de forma segura.

import SwiftUI

struct RecommendationsView: View {

    let recommendations: [WellnessRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.msAccent)
                Text("Recomendaciones de hoy")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            if recommendations.isEmpty {
                Text("Tus datos están en línea con tus objetivos. ¡Sigue así!")
                    .font(.msBody)
                    .foregroundStyle(.msTextSecondary)
            } else {
                ForEach(recommendations) { rec in
                    recommendationRow(rec)
                }
            }

            Text("Basadas en tus datos y objetivos personales. No sustituyen consejo médico.")
                .font(.system(size: 9.5))
                .foregroundStyle(.msTextTertiary)
        }
        .padding(16)
        .glassCard()
    }

    private func recommendationRow(_ rec: WellnessRecommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rec.type.icon)
                .foregroundStyle(typeColor(rec.type))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(rec.title)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
                Text(rec.message)
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.msSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func typeColor(_ type: WellnessRecommendation.RecommendationType) -> Color {
        switch type {
        case .sleep:     return .msSleep
        case .activity:  return .msActivity
        case .hydration: return .msLabs
        case .nutrition: return .msNutrition
        case .recovery:  return .msCardio
        }
    }
}
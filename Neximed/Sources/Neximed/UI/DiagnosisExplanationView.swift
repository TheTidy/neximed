// Neximed — DiagnosisExplanationView.swift
// Explica un diagnóstico dado por el médico en lenguaje sencillo (educativo).

import SwiftUI

struct DiagnosisExplanationView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var agent = HealthAgent.shared
    @State private var diagnosis = ""
    @State private var explanation = ""
    @State private var isExplaining = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Campo del diagnóstico
                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Qué diagnóstico te ha dado tu médico?")
                        .font(.msHeadline)
                        .foregroundStyle(.msTextPrimary)
                    TextField("Ej: hipotiroidismo, sarcoidosis...", text: $diagnosis)
                        .font(.msBody)
                        .padding(12)
                        .background(Color.msSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Botón explicar
                Button {
                    Task { await runExplanation() }
                } label: {
                    HStack {
                        if isExplaining {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isExplaining ? "Explicando..." : "Explicar en lenguaje sencillo")
                    }
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.msAgentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(diagnosis.trimmingCharacters(in: .whitespaces).isEmpty || isExplaining)

                // Resultado
                if !explanation.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "text.book.closed.fill")
                                    .foregroundStyle(.msAccent)
                                Text("Entendiendo \"\(diagnosis)\"")
                                    .font(.msHeadline)
                                    .foregroundStyle(.msTextPrimary)
                            }
                            Text(explanation)
                                .font(.msBody)
                                .foregroundStyle(.msTextPrimary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.msSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .scrollIndicators(.hidden)
                }

                Spacer()

                Text("Explicación educativa. No sustituye la valoración ni el tratamiento indicado por tu médico.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.msTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(Color.msBackground)
            .navigationTitle("Entender diagnóstico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func runExplanation() async {
        isExplaining = true
        explanation = ""
        explanation = await agent.explainDiagnosis(diagnosis.trimmingCharacters(in: .whitespaces))
        isExplaining = false
    }
}

#Preview {
    DiagnosisExplanationView()
}
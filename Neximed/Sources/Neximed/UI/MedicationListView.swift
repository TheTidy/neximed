// Neximed — MedicationListView.swift
// Botiquín: lista de medicamentos y suplementos con acceso al detalle,
// registro de tomas y explicación de diagnóstico.

import SwiftUI
import SwiftData

struct MedicationListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MedicationEntry.name) private var medications: [MedicationEntry]
    @State private var showAddSheet = false
    @State private var showDiagnosisSheet = false

    var body: some View {
        NavigationStack {
        ScrollView {
            LazyVStack(spacing: 16) {

                sectionHeader(
                    icon: "pills.fill",
                    title: "Botiquín",
                    subtitle: "Medicación, suplementos y tomas",
                    color: .msCardio
                )

                // Explicación de diagnóstico
                Button { showDiagnosisSheet = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.msAccent)
                            .frame(width: 36, height: 36)
                            .background(Color.msAccent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entender mi diagnóstico")
                                .font(.msBodyEmphasized)
                                .foregroundStyle(.msTextPrimary)
                            Text("Explica en lenguaje sencillo lo que te dijo tu médico")
                                .font(.msCaption)
                                .foregroundStyle(.msTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.msTextTertiary)
                    }
                    .padding(14)
                    .background(Color.msSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Botón añadir
                Button { showAddSheet = true } label: {
                    Label("Añadir medicamento o suplemento", systemImage: "plus.circle.fill")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.msCardioGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Lista
                if medications.isEmpty {
                    EmptyStateCard(
                        image: "empty-medications",
                        title: "Botiquín vacío",
                        subtitle: "Añade tu medicación y suplementos para incluirlos en tu dossier médico."
                    )
                } else {
                    ForEach(medications) { med in
                        NavigationLink {
                            MedicationDetailView(medication: med)
                        } label: {
                            medicationRow(med)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showAddSheet) {
            AddMedicationSheet { med in
                modelContext.insert(med)
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showDiagnosisSheet) {
            DiagnosisExplanationView()
        }
        .navigationTitle("Botiquín")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
        }
    }

    private func medicationRow(_ med: MedicationEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((med.type == .supplement ? Color.msNutrition : Color.msCardio).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: med.type == .supplement ? "leaf.fill" : "pills.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(med.type == .supplement ? Color.msNutrition : Color.msCardio)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(med.name)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
                Text("\(med.dosage) · \(med.intakeScheduleText)")
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
                if !med.experiencedSideEffects.isEmpty {
                    Text("Efectos: \(med.experiencedSideEffects.joined(separator: ", "))")
                        .font(.system(size: 10))
                        .foregroundStyle(.msWarning)
                }
            }
            Spacer()

            if med.reminderEnabled {
                Image(systemName: "bell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.msAccent)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.msTextTertiary)
        }
        .padding(12)
        .background(Color.msSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(med.isCurrent ? Color.msBorder.opacity(0.4) : Color.msBorder.opacity(0.2), lineWidth: 0.5)
        )
        .opacity(med.isCurrent ? 1 : 0.6)
    }
}

// MARK: - Hoja para añadir medicamento

struct AddMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (MedicationEntry) -> Void

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var type: MedicationEntry.MedicationType = .prescription

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Nombre (ej: Eutirox)", text: $name)
                    .fieldStyle()
                TextField("Dosis (ej: 50 mcg)", text: $dosage)
                    .fieldStyle()
                TextField("Frecuencia (ej: cada mañana)", text: $frequency)
                    .fieldStyle()

                Picker("Tipo", selection: $type) {
                    ForEach(MedicationEntry.MedicationType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    let med = MedicationEntry(name: name, dosage: dosage, frequency: frequency, type: type)
                    onAdd(med)
                    dismiss()
                } label: {
                    Text("Añadir");
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.msCardioGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(name.isEmpty || dosage.isEmpty)
                Spacer()
            }
            .padding(20)
            .background(Color.msBackground)
            .navigationTitle("Añadir medicamento")
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

// MARK: - Extensión para estilo de campo

extension View {
    func fieldStyle() -> some View {
        self.font(.msBody)
            .foregroundStyle(.msTextPrimary)
            .padding(12)
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
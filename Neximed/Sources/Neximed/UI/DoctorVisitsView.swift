// Neximed — DoctorVisitsView.swift
// Diario Post-Consulta (Hito E1): registra las visitas al médico, las pautas
// recibidas y programa el recordatorio de la próxima revisión.

import SwiftUI
import SwiftData

// MARK: - Diario médico (lista de consultas)

struct DoctorVisitsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DoctorVisitRecord.visitDate, order: .reverse)
    private var visits: [DoctorVisitRecord]

    @State private var showAddVisit = false
    @State private var selectedVisit: DoctorVisitRecord?

    var body: some View {
        ZStack {
            // Fondo de marca sutil (asset background-global, antes sin uso)
            Image("background-global")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.06)

            ScrollView {
                LazyVStack(spacing: 16) {
                    headerCard

                    if visits.isEmpty {
                        EmptyStateCard(
                            image: "illustration-dossier",
                            title: "Sin consultas registradas",
                            subtitle: "Añade tu primera visita médica para guardar las pautas del doctor y programar la próxima revisión."
                        )
                    } else {
                        ForEach(visits) { visit in
                            visitRow(visit)
                                .onTapGesture { selectedVisit = visit }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Diario médico")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showAddVisit = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir consulta")
            }
        }
        .sheet(isPresented: $showAddVisit) {
            AddVisitSheet()
        }
        .sheet(item: $selectedVisit) { visit in
            DoctorVisitDetailView(visit: visit)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Cabecera

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image("illustration-dossier")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(0.95)

            Text("Tu historial de consultas")
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)

            Text("Guarda las pautas de cada visita y Neximed te recordará la próxima revisión.")
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
    }

    // MARK: - Fila de consulta

    private func visitRow(_ visit: DoctorVisitRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "stethoscope")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.msSleep)
                .frame(width: 36, height: 36)
                .background(Color.msSleep.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(visit.specialty)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
                HStack(spacing: 6) {
                    Text(visit.visitDate.formatted(date: .abbreviated, time: .omitted))
                    if let next = visit.nextReviewDate {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.msAccent)
                        Text("Revisión \(next.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.msCaption)
                .foregroundStyle(.msTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.msTextTertiary)
        }
        .padding(14)
        .background(Color.msSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Nueva consulta

struct AddVisitSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notifications = NotificationManager.shared

    @State private var specialty = ""
    @State private var doctorName = ""
    @State private var clinic = ""
    @State private var visitDate = Date()
    @State private var reasons = ""
    @State private var instructions = ""
    @State private var remindReview = false
    @State private var reviewDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TextField("Especialidad (ej: Cardiología)", text: $specialty)
                        .fieldStyle()
                    TextField("Médico (opcional)", text: $doctorName)
                        .fieldStyle()
                    TextField("Centro u hospital (opcional)", text: $clinic)
                        .fieldStyle()

                    DatePicker("Fecha de la consulta", selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                        .font(.msBody)
                        .foregroundStyle(.msTextPrimary)
                        .padding(12)
                        .background(Color.msSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    TextField("Motivos (separados por coma)", text: $reasons)
                        .fieldStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pautas del doctor")
                            .font(.msCaption)
                            .foregroundStyle(.msTextSecondary)
                        TextEditor(text: $instructions)
                            .font(.msBody)
                            .foregroundStyle(.msTextPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)
                            .padding(10)
                            .background(Color.msSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Recordarme la próxima revisión", isOn: $remindReview)
                            .font(.msBodyEmphasized)
                            .tint(.msAccent)
                        if remindReview {
                            DatePicker("Fecha de revisión", selection: $reviewDate, displayedComponents: [.date, .hourAndMinute])
                                .font(.msBody)
                        }
                    }
                    .padding(12)
                    .background(Color.msSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: saveVisit) {
                        Text("Guardar consulta")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.msSleepGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(specialty.isEmpty)

                    Spacer(minLength: 30)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Color.msBackground)
            .navigationTitle("Nueva consulta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveVisit() {
        let reasonsList = reasons
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let visit = DoctorVisitRecord(
            specialty: specialty,
            visitDate: visitDate,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            clinicOrHospital: clinic.isEmpty ? nil : clinic,
            reasonsForVisit: reasonsList,
            doctorInstructions: instructions,
            nextReviewDate: remindReview ? reviewDate : nil
        )
        modelContext.insert(visit)
        try? modelContext.save()

        // Conectar con el recordatorio existente de "Próxima cita médica"
        if remindReview, reviewDate > Date() {
            notifications.scheduleOneShot(.appointment, at: reviewDate)
        }
        dismiss()
    }
}

// MARK: - Detalle de consulta

struct DoctorVisitDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notifications = NotificationManager.shared

    let visit: DoctorVisitRecord

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Cabecera
                    HStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.msSleep)
                            .frame(width: 44, height: 44)
                            .background(Color.msSleep.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.specialty)
                                .font(.msHeadline)
                                .foregroundStyle(.msTextPrimary)
                            Text(visit.doctorName ?? "Médico")
                                .font(.msCaption)
                                .foregroundStyle(.msTextSecondary)
                        }
                        Spacer()
                        Text(visit.visitDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.msCaption)
                            .foregroundStyle(.msTextTertiary)
                    }
                    .padding(16)
                    .glassCard()

                    if !visit.reasonsForVisit.isEmpty {
                        infoBlock(title: "Motivos de consulta", icon: "list.bullet.clipboard", color: .msLabs) {
                            ForEach(visit.reasonsForVisit, id: \.self) { reason in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.msLabs.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                    Text(reason)
                                        .font(.msBody)
                                        .foregroundStyle(.msTextPrimary)
                                }
                            }
                        }
                    }

                    if !visit.doctorInstructions.isEmpty {
                        infoBlock(title: "Pautas del doctor", icon: "text.book.closed.fill", color: .msNutrition) {
                            Text(visit.doctorInstructions)
                                .font(.msBody)
                                .foregroundStyle(.msTextPrimary)
                        }
                    }

                    // Próxima revisión + recordatorio
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.msAccent)
                            Text("Próxima revisión")
                                .font(.msBodyEmphasized)
                                .foregroundStyle(.msTextPrimary)
                            Spacer()
                        }

                        Toggle("Recordarme la revisión", isOn: reminderBinding)
                            .tint(.msAccent)

                        if notifications.isEnabled(.appointment) {
                            DatePicker("Fecha", selection: reviewDateBinding, displayedComponents: [.date, .hourAndMinute])
                                .font(.msBody)
                        } else if let next = visit.nextReviewDate {
                            Text("Revisión prevista el \(next.formatted(date: .abbreviated, time: .shortened)) (sin recordatorio)")
                                .font(.msCaption)
                                .foregroundStyle(.msTextTertiary)
                        }
                    }
                    .padding(16)
                    .glassCard()

                    Button(role: .destructive) {
                        deleteVisit()
                    } label: {
                        Label("Eliminar consulta", systemImage: "trash")
                            .font(.msBodyEmphasized)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(14)
                    .background(Color.msDanger.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Detalle de consulta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoBlock<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { notifications.isEnabled(.appointment) },
            set: { isOn in
                if isOn {
                    if let next = visit.nextReviewDate {
                        notifications.scheduleOneShot(.appointment, at: next)
                    }
                } else {
                    notifications.cancel(.appointment)
                }
            }
        )
    }

    private var reviewDateBinding: Binding<Date> {
        Binding(
            get: { visit.nextReviewDate ?? Date() },
            set: { newDate in
                visit.nextReviewDate = newDate
                try? modelContext.save()
                notifications.scheduleOneShot(.appointment, at: newDate)
            }
        )
    }

    private func deleteVisit() {
        notifications.cancel(.appointment)
        modelContext.delete(visit)
        try? modelContext.save()
        dismiss()
    }
}

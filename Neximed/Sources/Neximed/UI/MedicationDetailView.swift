// Neximed — MedicationDetailView.swift
// Detalle de un medicamento: dosis por toma, horarios, recordatorios,
// efectos secundarios y registro de tomas confirmadas.

import SwiftUI
import SwiftData

struct MedicationDetailView: View {

    @Bindable var medication: MedicationEntry
    @Environment(\.modelContext) private var modelContext

    @State private var notifications = NotificationManager.shared
    @State private var newSideEffect = ""

    @Query(sort: \MedicationDoseLog.takenAt, order: .reverse) private var doseLogs: [MedicationDoseLog]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {

                // Cabecera
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(medication.type == .supplement ? .msNutrition : .msCardio)
                        Text(medication.name)
                            .font(.msTitle)
                            .foregroundStyle(.msTextPrimary)
                    }
                    Text("\(medication.dosage) · \(medication.frequency) · \(medication.type.rawValue)")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard()

                // Dosis por toma
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Dosis por toma", icon: "scalemass.fill")
                    TextField("Ej: 50 mcg, 1 comprimido", text: $medication.dosePerIntake.boundSafe)
                        .font(.msBody)
                        .padding(10)
                        .background(Color.msSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
                .glassCard()

                // Horarios y recordatorio
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Horarios de toma", icon: "clock.fill")

                    // Lista de horarios con DatePicker inline
                    ForEach(medication.intakeTimes.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.msAccent)
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { timeFromString(medication.intakeTimes[index]) },
                                    set: { medication.intakeTimes[index] = timeToString($0); save() }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            Button {
                                medication.intakeTimes.remove(at: index)
                                save()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.msDanger)
                            }
                        }
                    }

                    // Añadir horario
                    Button {
                        medication.intakeTimes.append("08:00")
                        save()
                    } label: {
                        Label("Añadir toma", systemImage: "plus.circle.fill")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.msAccent)
                    }

                    Divider().overlay(Color.msBorder.opacity(0.5))

                    // Activar recordatorio
                    Toggle("Recordatorio de tomas", isOn: $medication.reminderEnabled.boundBool)
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msTextPrimary)
                        .tint(.msCardio)
                        .onChange(of: medication.reminderEnabled) { _, enabled in
                            scheduleReminder(enabled: enabled)
                        }
                }
                .padding(16)
                .glassCard()

                // Efectos secundarios
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Efectos secundarios", icon: "exclamationmark.triangle.fill")

                    if !medication.sideEffects.isEmpty {
                        Text("Posibles (según prospecto):")
                            .font(.msCaption)
                            .foregroundStyle(.msTextSecondary)
                        ForEach(medication.sideEffects, id: \.self) { effect in
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.msWarning)
                                Text(effect)
                                    .font(.msBody)
                                    .foregroundStyle(.msTextPrimary)
                                Spacer()
                            }
                        }
                    } else {
                        Text("No se han añadido efectos secundarios conocidos.")
                            .font(.msCaption)
                            .foregroundStyle(.msTextTertiary)
                    }

                    // Añadir efecto secundario
                    HStack {
                        TextField("Añadir efecto (ej: mareo)", text: $newSideEffect)
                            .font(.msBody)
                            .padding(10)
                            .background(Color.msSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button {
                            let effect = newSideEffect.trimmingCharacters(in: .whitespaces)
                            if !effect.isEmpty {
                                medication.sideEffects.append(effect)
                                newSideEffect = ""
                                save()
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.msAccent)
                        }
                    }
                }
                .padding(16)
                .glassCard()

                // Registro de tomas recientes
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Historial de tomas", icon: "checkmark.circle.fill")

                    let logs = doseLogs.filter { $0.medicationName == medication.name }.prefix(10)
                    if logs.isEmpty {
                        Text("Sin tomas registradas todavía.")
                            .font(.msCaption)
                            .foregroundStyle(.msTextTertiary)
                    } else {
                        ForEach(Array(logs)) { log in
                            HStack {
                                Image(systemName: log.skipped ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(log.skipped ? .msDanger : .msGood)
                                Text(log.skipped ? "Omitida" : "Tomada")
                                    .font(.msBody)
                                    .foregroundStyle(.msTextPrimary)
                                if let dose = log.dose {
                                    Text(dose)
                                        .font(.msCaption)
                                        .foregroundStyle(.msTextSecondary)
                                }
                                Spacer()
                                Text(log.takenAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.msTextTertiary)
                            }
                        }
                    }

                    // Botones rápidos
                    HStack(spacing: 10) {
                        Button { logDose(skipped: false) } label: {
                            Label("Tomada", systemImage: "checkmark");
                                .font(.msBodyEmphasized)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.msGood)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button { logDose(skipped: true) } label: {
                            Label("Omitida", systemImage: "xmark");
                                .font(.msBodyEmphasized)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.msDanger.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
                .glassCard()

                // Aviso legal
                Text("La información de medicamentos es orientativa. Consulta siempre el prospecto y a tu médico o farmacéutico.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.msTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.msAccent)
            Text(title)
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)
        }
    }

    private func save() {
        try? modelContext.save()
    }

    private func timeFromString(_ s: String) -> Date {
        let comps = s.split(separator: ":").compactMap { Int($0) }
        var date = Calendar.current.date(bySettingHour: comps.count > 0 ? comps[0] : 8, minute: comps.count > 1 ? comps[1] : 0, second: 0, of: Date()) ?? Date()
        return date
    }

    private func timeToString(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 8, comps.minute ?? 0)
    }

    /// Programa o cancela el recordatorio de este medicamento
    private func scheduleReminder(enabled: Bool) {
        if enabled {
            for time in medication.intakeTimes {
                let comps = time.split(separator: ":").compactMap { Int($0) }
                guard comps.count == 2 else { continue }
                let minutes = comps[0] * 60 + comps[1]
                let id = "med-\(medication.id.uuidString)-\(time)"
                notifications.scheduleMedicationDose(
                    id: id,
                    name: medication.name,
                    dose: medication.dosePerIntake ?? medication.dosage,
                    at: minutes
                )
            }
        } else {
            // Cancelar todos los recordatorios de este medicamento
            notifications.cancelMedicationDoses(for: medication.id.uuidString)
        }
    }

    private func logDose(skipped: Bool) {
        let log = MedicationDoseLog(
            medicationName: medication.name,
            dose: medication.dosePerIntake ?? medication.dosage,
            skipped: skipped,
            reasonSkipped: skipped ? "Efectos secundarios u olvido" : nil
        )
        modelContext.insert(log)
        try? modelContext.save()
    }
}

// MARK: - Binding seguro para optionals en TextField/Toggle

extension Binding where Value == String? {
    var boundSafe: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension Binding where Value == Bool {
    var boundBool: Binding<Bool> { self }
}
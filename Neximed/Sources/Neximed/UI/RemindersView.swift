// Neximed — RemindersView.swift
// Gestión de recordatorios: medicación, hidratación, cita médica y check-in diario.

import SwiftUI

struct RemindersView: View {

    @State private var notifications = NotificationManager.shared

    // Horarios configurables
    @State private var medicationTime = Date()
    @State private var checkInTime = Date()
    @State private var appointmentDate = Date()
    @State private var hydrationInterval = 2
    @State private var hydrationStart = Date()
    @State private var hydrationEnd = Date()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {

                sectionHeader(
                    icon: "bell.badge.fill",
                    title: "Recordatorios",
                    subtitle: "Neximed te avisa para que no pierdas el hábito",
                    color: .msAccent
                )

                medicationCard
                hydrationCard
                checkInCard
                appointmentCard

                Text("Los recordatorios son 100% locales y se procesan en tu dispositivo.")
                    .font(.system(size: 10))
                    .foregroundStyle(.msTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Medicación

    private var medicationCard: some View {
        ReminderCard(
            title: "Medicación",
            icon: "pills.fill",
            color: .msCardio,
            isEnabled: notifications.isEnabled(.medication),
            onToggle: { enabled in
                if enabled {
                    let minutes = Int(medicationTime.timeIntervalSince1970) % 86400 / 60
                    notifications.scheduleDaily(.medication, at: minutes)
                } else {
                    notifications.cancel(.medication)
                }
            }
        ) {
            DatePicker("Hora", selection: $medicationTime, displayedComponents: .hourAndMinute)
        }
    }

    // MARK: - Hidratación

    private var hydrationCard: some View {
        ReminderCard(
            title: "Hidratación",
            icon: "drop.fill",
            color: .msLabs,
            isEnabled: notifications.isEnabled(.hydration),
            onToggle: { enabled in
                if enabled {
                    notifications.scheduleHydration(
                        every: hydrationInterval,
                        from: minutes(hydrationStart),
                        to: minutes(hydrationEnd)
                    )
                } else {
                    notifications.cancel(.hydration)
                }
            }
        ) {
            Stepper("Cada \(hydrationInterval) h", value: $hydrationInterval, in: 1...4)
            DatePicker("Desde", selection: $hydrationStart, displayedComponents: .hourAndMinute)
            DatePicker("Hasta", selection: $hydrationEnd, displayedComponents: .hourAndMinute)
        }
    }

    // MARK: - Check-in diario

    private var checkInCard: some View {
        ReminderCard(
            title: "Check-in de bienestar",
            icon: "face.smiling.fill",
            color: .msNutrition,
            isEnabled: notifications.isEnabled(.dailyCheckIn),
            onToggle: { enabled in
                if enabled {
                    let minutes = Int(checkInTime.timeIntervalSince1970) % 86400 / 60
                    notifications.scheduleDaily(.dailyCheckIn, at: minutes)
                } else {
                    notifications.cancel(.dailyCheckIn)
                }
            }
        ) {
            DatePicker("Hora", selection: $checkInTime, displayedComponents: .hourAndMinute)
        }
    }

    // MARK: - Cita médica (recordatorio único en la fecha elegida)

    private var appointmentCard: some View {
        ReminderCard(
            title: "Próxima cita médica",
            icon: "stethoscope",
            color: .msSleep,
            isEnabled: notifications.isEnabled(.appointment),
            onToggle: { enabled in
                if enabled {
                    notifications.scheduleOneShot(.appointment, at: appointmentDate)
                } else {
                    notifications.cancel(.appointment)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                DatePicker(
                    "Fecha de la cita",
                    selection: $appointmentDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                if let scheduled = notifications.storedAppointmentDate() {
                    Text("Recordatorio el \(scheduled.formatted(date: .abbreviated, time: .shortened))")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
            }
        }
        .onAppear {
            if let stored = notifications.storedAppointmentDate() {
                appointmentDate = stored
            } else {
                appointmentDate = Self.defaultAppointmentDate()
            }
        }
        // Si el usuario cambia la fecha con el recordatorio activo, se reprograma
        .onChange(of: appointmentDate) { _, newDate in
            if notifications.isEnabled(.appointment) {
                notifications.scheduleOneShot(.appointment, at: newDate)
            }
        }
    }

    /// Fecha por defecto: mañana a las 09:00 (suficiente margen para preparar el dossier)
    private static func defaultAppointmentDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func minutes(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 8) * 60 + (comps.minute ?? 0)
    }
}

// MARK: - Tarjeta de recordatorio reutilizable

struct ReminderCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    @ViewBuilder let content: Content

    @State private var isOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
                Spacer()

                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        isOn = newValue
                        onToggle(newValue)
                    }
                ))
                .labelsHidden()
                .tint(color)
            }

            if isOn {
                content
                    .font(.msBody)
                    .foregroundStyle(.msTextPrimary)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .glassCard()
        .onAppear { isOn = isEnabled }
        .onChange(of: isEnabled) { _, newVal in
            isOn = newVal
        }
    }
}
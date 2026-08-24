// Neximed — NotificationManager.swift
// Gestión de recordatorios locales (UNUserNotificationCenter):
//  - Medicación (hora diaria + confirmación de toma)
//  - Hidratación (intervalo en horas activas)
//  - Próxima cita médica (fecha concreta)
//  - Check-in diario de bienestar (hora configurable)
//
// TODO es 100% local: sin servidores, sin push remoto.

import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class NotificationManager {

    static let shared = NotificationManager()

    // MARK: - Identificadores de notificaciones

    enum ReminderType: String, CaseIterable, Identifiable {
        case medication = "medication"
        case hydration = "hydration"
        case appointment = "appointment"
        case dailyCheckIn = "daily_checkin"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .medication:  return "Recordatorio de medicación"
            case .hydration:   return "Recuerda hidratarte"
            case .appointment: return "Próxima cita médica"
            case .dailyCheckIn: return "Check-in de bienestar"
            }
        }

        var defaultBody: String {
            switch self {
            case .medication:  return "Es hora de tomar tu medicación."
            case .hydration:   return "Tómate un vaso de agua. 💧"
            case .appointment: return "Tienes una consulta próxima. Prepara tu dossier."
            case .dailyCheckIn: return "¿Cómo te sientes hoy? Cuéntaselo a Neximed."
            }
        }
    }

    // MARK: - Estado

    private(set) var isAuthorized = false
    private(set) var lastError: String?

    // Configuración persistida (qué recordatorios están activos y sus horarios)
    private let defaults = UserDefaults.standard

    private init() {
        Task { await requestAuthorization() }
    }

    // MARK: - Permisos

    func requestAuthorization() async {
        do {
            isAuthorized = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Configuración persistente

    /// Hora (minutos desde medianoche) para un tipo de recordatorio. nil = desactivado
    func storedTime(for type: ReminderType) -> Int? {
        let key = "reminder.\(type.rawValue)"
        return defaults.object(forKey: key) as? Int
    }

    func isEnabled(_ type: ReminderType) -> Bool {
        storedTime(for: type) != nil
    }

    // MARK: - Programación de recordatorios

    /// Programa un recordatorio diario recurrente a una hora concreta
    func scheduleDaily(_ type: ReminderType, at minutesFromMidnight: Int, body: String? = nil) {
        let center = UNUserNotificationCenter.current()

        // Cancelar el anterior del mismo tipo (evitar duplicados)
        center.removePendingNotificationRequests(withIdentifiers: [type.rawValue]);

        var components = DateComponents()
        components.hour = minutesFromMidnight / 60
        components.minute = minutesFromMidnight % 60

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = body ?? type.defaultBody
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)

        center.add(request)
        defaults.set(minutesFromMidnight, forKey: "reminder.\(type.rawValue)")
    }

    /// Programa un recordatorio diario de dosis de medicación (con nombre y dosis)
    func scheduleMedicationDose(id: String, name: String, dose: String, at minutesFromMidnight: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        var components = DateComponents()
        components.hour = minutesFromMidnight / 60
        components.minute = minutesFromMidnight % 60

        let content = UNMutableNotificationContent()
        content.title = "💊 \(name)"
        content.body = "Es hora de tu dosis: \(dose)"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Cancela todas las dosis programadas de un medicamento (por su UUID)
    func cancelMedicationDoses(for medicationID: String) {
        let center = UNUserNotificationCenter.current()
        let prefix = "med-\(medicationID)"
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Programa un recordatorio único (ej. cita médica en una fecha)
    func scheduleOneShot(_ type: ReminderType, at date: Date, body: String? = nil) {
        guard date > Date() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [type.rawValue]);

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = body ?? type.defaultBody
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)

        center.add(request)
        // Guardar timestamp para mostrarlo en la UI
        defaults.set(date.timeIntervalSince1970, forKey: "reminder.appointment.date")
    }

    /// Programa el intervalo de hidratación (cada N horas entre hora inicio y fin)
    func scheduleHydration(every hours: Int, from startMinutes: Int, to endMinutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ReminderType.hydration.rawValue]);

        guard hours > 0 else { return }

        // Programar una notificación por cada intervalo en la ventana activa
        var minute = startMinutes
        var index = 0
        while minute < endMinutes {
            var components = DateComponents()
            components.hour = minute / 60
            components.minute = minute % 60

            let content = UNMutableNotificationContent()
            content.title = ReminderType.hydration.title
            content.body = ReminderType.hydration.defaultBody
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "\(ReminderType.hydration.rawValue)-\(index)"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger));
            index += 1
            minute += hours * 60
        }

        defaults.set(hours, forKey: "reminder.hydration.interval")
        defaults.set(startMinutes, forKey: "reminder.hydration.start")
        defaults.set(endMinutes, forKey: "reminder.hydration.end")
    }

    // MARK: - Cancelar recordatorios

    func cancel(_ type: ReminderType) {
        let center = UNUserNotificationCenter.current()

        if type == .hydration {
            // Cancelar todas las instancias del intervalo
            center.getPendingNotificationRequests { requests in
                let ids = requests.filter { $0.identifier.hasPrefix(ReminderType.hydration.rawValue) }.map(\.identifier)
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [type.rawValue]);
        }

        defaults.removeObject(forKey: "reminder.\(type.rawValue)")
        if type == .appointment {
            defaults.removeObject(forKey: "reminder.appointment.date")
        }
        if type == .hydration {
            defaults.removeObject(forKey: "reminder.hydration.interval")
            defaults.removeObject(forKey: "reminder.hydration.start")
            defaults.removeObject(forKey: "reminder.hydration.end")
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for type in ReminderType.allCases {
            defaults.removeObject(forKey: "reminder.\(type.rawValue)")
        }
        defaults.removeObject(forKey: "reminder.appointment.date")
        defaults.removeObject(forKey: "reminder.hydration.interval")
        defaults.removeObject(forKey: "reminder.hydration.start")
        defaults.removeObject(forKey: "reminder.hydration.end")
    }

    /// Pide autorización para notificaciones si aún no se ha concedido
    func ensureAuthorized() async {
        if !isAuthorized {
            await requestAuthorization()
        }
    }
}
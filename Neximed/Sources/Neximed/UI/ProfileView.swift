// Neximed — ProfileView.swift
// Perfil completo del usuario: datos personales, ficha clínica, dieta,
// trabajo, hábitos digitales y contacto de emergencia.

import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var healthKit = HealthKitManager.shared
    @Query private var profiles: [UserProfile]

    var profile: UserProfile? { profiles.first }

    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var showMedicationSheet = false
    @State private var showRemindersSheet = false
    @State private var showDoctorVisitsSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                sectionHeader(
                    icon: "person.crop.circle.fill",
                    title: "Mi Perfil",
                    subtitle: "Datos que usa Neximed para contextualizar tu salud",
                    color: .msAccent
                )

                if let profile {
                    demographicSection(profile)
                    clinicalSection(profile)
                    nutritionSection(profile)
                    workSection(profile)
                    screenTimeSection(profile)
                    languageSection
                    emergencySection(profile)
                    medicationSection
                    doctorVisitsSection
                    remindersSection
                    dataExportSection
                } else {
                    Text("Completa tu perfil para obtener un contexto más preciso.")
                        .font(.msBody)
                        .foregroundStyle(.msTextSecondary)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showMedicationSheet) {
            MedicationListView()
        }
        .sheet(isPresented: $showRemindersSheet) {
            RemindersView()
        }
        .sheet(isPresented: $showDoctorVisitsSheet) {
            DoctorVisitsView()
        }
    }

    // MARK: - Datos demográficos

    private func demographicSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Datos personales", icon: "person.fill", color: .msAccent)

            ProfileField(title: "Fecha de nacimiento") {
                DatePicker("", selection: Binding(
                    get: { p.birthDate ?? Date() },
                    set: { p.birthDate = $0; save(p) }
                ), displayedComponents: .date)
                .labelsHidden()
            }

            ProfileField(title: "Sexo") {
                Picker("", selection: Binding(
                    get: { p.biologicalSex ?? "Prefiero no decirlo" },
                    set: { p.biologicalSex = $0; save(p) }
                )) {
                    Text("Hombre").tag("Hombre")
                    Text("Mujer").tag("Mujer")
                    Text("Prefiero no decirlo").tag("Prefiero no decirlo")
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                ProfileField(title: "Altura (cm)", flex: 1) {
                    TextField("cm", value: Binding(
                        get: { p.heightCm ?? 0 },
                        set: { p.heightCm = $0 > 0 ? $0 : nil; save(p) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
                ProfileField(title: "Peso (kg)", flex: 1) {
                    TextField("kg", value: Binding(
                        get: { p.weightKg ?? 0 },
                        set: { p.weightKg = $0 > 0 ? $0 : nil; save(p) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }

            if let bmi = p.bmi {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.msAccent)
                    Text("IMC: \(String(format: "%.1f", bmi)) — valor orientativo")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Ficha clínica

    private func clinicalSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Ficha clínica", icon: "cross.case.fill", color: .msLabs)

            ProfileField(title: "Grupo sanguíneo") {
                Picker("", selection: Binding(
                    get: { p.bloodType ?? "Desconocido" },
                    set: { p.bloodType = $0; save(p) }
                )) {
                    Text("Desconocido").tag("Desconocido")
                    ForEach(["A+", "A-", "B+", "B-", "AB+", "AB-", "0+", "0-"], id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
            }

            ProfileField(title: "Patologías previas (una por línea)") {
                TextEditor(text: Binding(
                    get: { p.chronicConditions.joined(separator: "\n") },
                    set: {
                        p.chronicConditions = $0
                            .split(separator: "\n")
                            .map(String.init)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        save(p)
                    }
                ))
                .font(.msBody)
                .frame(minHeight: 60)
                .padding(8)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            ProfileField(title: "Alergias medicamentosas (una por línea)") {
                TextEditor(text: Binding(
                    get: { p.allergies.joined(separator: "\n") },
                    set: {
                        p.allergies = $0
                            .split(separator: "\n")
                            .map(String.init)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        save(p)
                    }
                ))
                .font(.msBody)
                .frame(minHeight: 50)
                .padding(8)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // ALERGIAS ALIMENTARIAS — crítico para la seguridad al registrar comidas
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "allergens")
                        .foregroundStyle(.msDanger)
                    Text("Alergias alimentarias")
                        .font(.msCaption)
                        .foregroundStyle(.msDanger)
                }

                Text("Selecciona los alergenos que debes evitar. Neximed te avisará al registrar comidas que los contengan.")
                    .font(.system(size: 10))
                    .foregroundStyle(.msTextTertiary)

                // Chips seleccionables de los 14 alergenos de la UE
                FlowLayout(spacing: 8) {
                    ForEach(Allergen.euRequired) { allergen in
                        allergenChip(allergen, profile: p)
                    }
                }

                // Intolerancias comunes
                FlowLayout(spacing: 8) {
                    ForEach([Allergen.lactose, Allergen.histamine]) { allergen in
                        allergenChip(allergen, profile: p)
                    }
                }
            }
            .padding(10)
            .background(Color.msDanger.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ProfileField(title: "Tabaco") {
                Picker("", selection: Binding(
                    get: { p.smokingStatus ?? "Nunca fumador" },
                    set: { p.smokingStatus = $0; save(p) }
                )) {
                    Text("Nunca fumador").tag("Nunca fumador")
                    Text("Exfumador").tag("Exfumador")
                    Text("Fumador").tag("Fumador")
                }
                .pickerStyle(.segmented)
            }

            ProfileField(title: "Alcohol") {
                Picker("", selection: Binding(
                    get: { p.alcoholFrequency ?? "Ocasional" },
                    set: { p.alcoholFrequency = $0; save(p) }
                )) {
                    Text("Nunca").tag("Nunca")
                    Text("Ocasional").tag("Ocasional")
                    Text("Semanal").tag("Semanal")
                    Text("Diario").tag("Diario")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Nutrición y dieta

    private func nutritionSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Nutrición y dieta", icon: "fork.knife", color: .msNutrition)

            ProfileField(title: "Tipo de dieta") {
                Picker("", selection: Binding(
                    get: { p.dietType ?? "Omnívora" },
                    set: { p.dietType = $0; save(p) }
                )) {
                    ForEach(["Omnívora", "Mediterránea", "Vegetariana", "Vegana", "Keto", "Sin gluten", "Otra"], id: \.self) { d in
                        Text(d).tag(d)
                    }
                }
            }

            ProfileField(title: "Restricciones alimentarias (una por línea)") {
                TextEditor(text: Binding(
                    get: { p.dietaryRestrictions.joined(separator: "\n") },
                    set: {
                        p.dietaryRestrictions = $0
                            .split(separator: "\n")
                            .map(String.init)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        save(p)
                    }
                ))
                .font(.msBody)
                .frame(minHeight: 50)
                .padding(8)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            ProfileField(title: "Comidas al día") {
                Stepper("\(p.mealsPerDay) comidas", value: Binding(
                    get: { p.mealsPerDay },
                    set: { p.mealsPerDay = $0; save(p) }
                ), in: 1...6)
            }

            ProfileField(title: "Agua diaria aprox. (litros)") {
                TextField("L", value: Binding(
                    get: { p.waterIntakeLiters ?? 0 },
                    set: { p.waterIntakeLiters = $0 > 0 ? $0 : nil; save(p) }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Trabajo y rutina

    private func workSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trabajo y rutina", icon: "briefcase.fill", color: .msActivity)

            ProfileField(title: "Horario laboral") {
                Picker("", selection: Binding(
                    get: { p.workSchedule ?? "Diurno" },
                    set: { p.workSchedule = $0; save(p) }
                )) {
                    Text("Diurno").tag("Diurno")
                    Text("Nocturno").tag("Nocturno")
                    Text("Turnos rotativos").tag("Turnos rotativos")
                    Text("Teletrabajo").tag("Teletrabajo")
                    Text("Jubilado / Sin trabajo").tag("Jubilado / Sin trabajo")
                }
            }

            ProfileField(title: "Horas de trabajo semanales") {
                Stepper("\(p.workHoursPerWeek ?? 40) h/semana", value: Binding(
                    get: { p.workHoursPerWeek ?? 40 },
                    set: { p.workHoursPerWeek = $0; save(p) }
                ), in: 0...80, step: 5)
            }

            ProfileField(title: "Ritmo de sueño") {
                Picker("", selection: Binding(
                    get: { p.sleepSchedule ?? "Madrugador" },
                    set: { p.sleepSchedule = $0; save(p) }
                )) {
                    Text("Madrugador").tag("Madrugador")
                    Text("Noctámbulo").tag("Noctámbulo")
                    Text("Irregular").tag("Irregular")
                }
                .pickerStyle(.segmented)
            }

            ProfileField(title: "Actividad física") {
                Picker("", selection: Binding(
                    get: { p.physicalActivityLevel ?? "Moderado" },
                    set: { p.physicalActivityLevel = $0; save(p) }
                )) {
                    Text("Sedentario").tag("Sedentario")
                    Text("Ligero").tag("Ligero")
                    Text("Moderado").tag("Moderado")
                    Text("Intenso").tag("Intenso")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Hábitos digitales (horas de pantalla)

    private func screenTimeSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Hábitos digitales", icon: "iphone", color: .msSleep)

            ProfileField(title: "Horas de pantalla al día (aprox.)") {
                HStack {
                    TextField("h", value: Binding(
                        get: { p.avgScreenTimeHours ?? 0 },
                        set: { p.avgScreenTimeHours = $0 > 0 ? $0 : nil; save(p) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    Text("horas").font(.msCaption).foregroundStyle(.msTextTertiary)
                }
            }

            if p.screenTimeAutoTracked {
                Label("Medición automática de pantalla activa (Screen Time)", systemImage: "checkmark.circle.fill")
                    .font(.msCaption)
                    .foregroundStyle(.msGood)
            } else {
                Label("Medición automática pendiente de aprobación de Apple (Screen Time API)", systemImage: "clock.fill")
                    .font(.msCaption)
                    .foregroundStyle(.msTextTertiary)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Idioma de la app

    private var languageSection: some View {
        let language = LanguageManager.shared

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Idioma / Language", icon: "globe", color: .msAccentSecondary)

            ProfileField(title: "Idioma de la app") {
                Picker("", selection: Binding(
                    get: { language.currentLanguage },
                    set: { language.setLanguage($0) }
                )) {
                    ForEach(LanguageManager.AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            }

            Label("El reconocimiento de voz y la IA responderán en este idioma", systemImage: "mic.fill")
                .font(.msCaption)
                .foregroundStyle(.msTextTertiary)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Contacto de emergencia

    private func emergencySection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Contacto de emergencia (ICE)", icon: "cross.circle.fill", color: .msCardio)

            ProfileField(title: "Nombre") {
                TextField("Nombre del contacto", text: Binding(
                    get: { p.emergencyContactName ?? "" },
                    set: { p.emergencyContactName = $0; save(p) }
                ))
            }

            ProfileField(title: "Teléfono") {
                TextField("Número de teléfono", text: Binding(
                    get: { p.emergencyContactPhone ?? "" },
                    set: { p.emergencyContactPhone = $0; save(p) }
                ))
                .keyboardType(.phonePad)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)
        }
    }

    // MARK: - Chip de alergeno seleccionable

    private func allergenChip(_ allergen: Allergen, profile: UserProfile) -> some View {
        let isSelected = profile.foodAllergens.contains(allergen)
        return Button {
            if isSelected {
                profile.foodAllergens.removeAll { $0 == allergen }
            } else {
                profile.foodAllergens.append(allergen)
            }
            save(profile)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: allergen.icon)
                    .font(.system(size: 10))
                Text(allergen.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.white : Color.msTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.msDanger : Color.msSurfaceElevated)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.msDanger : Color.msBorder.opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func save(_ profile: UserProfile) {
        profile.lastUpdated = Date()
        try? modelContext.save()
    }

    // MARK: - Botiquín

    private var medicationSection: some View {
        Button { showMedicationSheet = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.msCardio)
                    .frame(width: 36, height: 36)
                    .background(Color.msCardio.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Botiquín")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msTextPrimary)
                    Text("Medicación, tomas y entender tu diagnóstico")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.msTextTertiary)
            }
            .padding(14)
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Diario médico (Post-Consulta)

    private var doctorVisitsSection: some View {
        Button { showDoctorVisitsSheet = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.msSleep)
                    .frame(width: 36, height: 36)
                    .background(Color.msSleep.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Diario médico")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msTextPrimary)
                    Text("Visitas, pautas del doctor y próxima revisión")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.msTextTertiary)
            }
            .padding(14)
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recordatorios

    private var remindersSection: some View {
        Button { showRemindersSheet = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.msAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.msAccent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recordatorios")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msTextPrimary)
                    Text("Medicación, hidratación y check-in diario")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.msTextTertiary)
            }
            .padding(14)
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exportación de datos

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tus datos", icon: "square.and.arrow.up", color: .msLabs)

            Text("Exporta tus datos en CSV o JSON para compartirlos con tu médico o guardar una copia.")
                .font(.msCaption)
                .foregroundStyle(.msTextSecondary)

            HStack(spacing: 10) {
                Button { exportData(format: .csv) } label: {
                    Label("CSV", systemImage: "tablecells")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.msLabs)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button { exportData(format: .json) } label: {
                    Label("JSON", systemImage: "curlybraces")
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.msSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Lógica de exportación

    private enum ExportFormat { case csv, json }

    private func exportData(format: ExportFormat) {
        guard let profile = profile else { return }

        // Recoger los datos (se consultan de HealthKit y SwiftData)
        let activity = healthKit.cachedActivity
        let cardio = healthKit.cachedCardio
        let sleep = healthKit.cachedSleep
        let nutrition = healthKit.cachedNutrition

        let weights = try? modelContext.fetch(FetchDescriptor<WeightEntry>())
        let symptoms = try? modelContext.fetch(FetchDescriptor<SymptomEntry>())
        let medications = try? modelContext.fetch(FetchDescriptor<MedicationEntry>())

        let data: Data?
        let filename: String
        if format == .csv {
            let csv = DataExporter.shared.exportCSV(
                profile: profile,
                activity: activity,
                cardio: cardio,
                sleep: sleep,
                nutrition: nutrition,
                weights: weights ?? [],
                symptoms: symptoms ?? []
            )
            data = csv.data(using: .utf8)
            filename = "neximed-export.csv"
        } else {
            data = DataExporter.shared.exportJSON(
                profile: profile,
                activity: activity,
                cardio: cardio,
                sleep: sleep,
                nutrition: nutrition,
                weights: weights ?? [],
                symptoms: symptoms ?? [],
                medications: medications ?? []
            )
            filename = "neximed-export.json"
        }

        guard let data else { return }

        // Guardar en archivos temporales y compartir
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        exportedFileURL = url
        showShareSheet = true
    }

}

// MARK: - Campo de perfil reutilizable

struct ProfileField<Content: View>: View {
    let title: String
    var flex: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.msCaption)
                .foregroundStyle(.msTextSecondary)
            content
                .font(.msBody)
                .foregroundStyle(.msTextPrimary)
                .padding(10)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: flex > 0 ? flex * 300 : .infinity)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
        .preferredColorScheme(.dark)
}

// MARK: - FlowLayout (layout simple de chips que fluyen en varias líneas)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}


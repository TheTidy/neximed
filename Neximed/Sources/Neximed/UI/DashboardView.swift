// Neximed — DashboardView.swift
// Panel principal: Resumen de constantes, dictado por voz inteligente y exportación médica en PDF

import SwiftUI
import SwiftData
import Charts
import PDFKit

struct DashboardView: View {

    @State private var healthKit = HealthKitManager.shared
    @State private var agent = HealthAgent.shared

    @Query private var profiles: [UserProfile]
    @Query private var medications: [MedicationEntry]
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var recentSymptoms: [SymptomEntry]

    var profile: UserProfile? { profiles.first }

    @State private var activityData: [ActivitySnapshot] = []
    @State private var cardioData: [CardioSnapshot] = []
    @State private var sleepData: [SleepSnapshot] = []
    @State private var nutritionData: [NutritionSnapshot] = []
    @State private var doctorPrep: HealthAgent.DoctorVisitSummary?
    @State private var isGeneratingPDF = false
    @State private var generatedPDFData: Data?
    @State private var showShareSheet = false
    @State private var showVoiceSheet = false
    @State private var showCheckIn = false
    @State private var recommendations: [WellnessRecommendation] = []

    private var todayActivity: ActivitySnapshot? { activityData.last }
    private var todayCardio: CardioSnapshot? { cardioData.last }
    private var todaySleep: SleepSnapshot? { sleepData.last }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {

                // MARK: Header de saludo
                greetingHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // MARK: Botonera Rápida: Dictado por Voz & Exportar PDF
                    actionButtonsGrid
                        .padding(.horizontal, 20)

                    // MARK: Preparación de Consulta Médica
                    if let prep = doctorPrep {
                        doctorPrepSection(prep)
                            .padding(.horizontal, 20)
                    }

                    // MARK: Recomendaciones de estilo de vida
                    if !recommendations.isEmpty {
                        RecommendationsView(recommendations: recommendations)
                            .padding(.horizontal, 20)
                    }

                    // MARK: Síntomas Recientes Dictados por Voz
                    if !recentSymptoms.isEmpty {
                        recentSymptomsSection
                            .padding(.horizontal, 20)
                    } else {
                        EmptyStateCard(
                            image: "empty-symptoms",
                            title: "Sin síntomas registrados",
                            subtitle: "Usa el dictado por voz para registrar cómo te sientes y llevar un historial para tu médico."
                        )
                        .padding(.horizontal, 20)
                    }

                    // MARK: Constantes Vitales (Apple Watch)
                    metricsGrid
                        .padding(.horizontal, 20)

                    // MARK: Anillo de objetivo de descanso
                    sleepGoalRing
                        .padding(.horizontal, 20)

                    // MARK: Gráfica de sueño
                    sleepChart
                        .padding(.horizontal, 20)

                    // MARK: Tendencia cardíaca
                    heartRateChart
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
        .task {
            // 1. Datos de HealthKit primero (rápido, queries en paralelo)
            await loadData()

            // 2. Preparación de consulta en Task independiente: no bloquea el dashboard
            //    (la IA puede tardar; el usuario ve los datos al instante)
            doctorPrep = await agent.generateDoctorVisitPrep()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData = generatedPDFData {
                ShareSheet(items: [pdfData])
            }
        }
        .sheet(isPresented: $showVoiceSheet) {
            VoiceDictationSheet(category: .symptom) { _ in
                Task {
                    doctorPrep = await agent.generateDoctorVisitPrep()
                }
            }
        }
        .sheet(isPresented: $showCheckIn) {
            DailyCheckInView()
        }
    }

    // MARK: - Saludo dinámico

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
                Text(profile?.name ?? "Usuario")
                    .font(.msDisplayMedium)
                    .foregroundStyle(.msTextPrimary)
            }
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient.msAgentGradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Buenos días • Cuaderno Clínico"
        case 12..<18: return "Buenas tardes • Cuaderno Clínico"
        default:      return "Buenas noches • Cuaderno Clínico"
        }
    }

    // MARK: - Botonera de Acciones Rápidas (Dictar por Voz & Exportar PDF)

    private var actionButtonsGrid: some View {
        VStack(spacing: 12) {
            // Botón 1: Dictado por Voz Inteligente
            Button(action: { showVoiceSheet = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.msAgentGradient)
                            .frame(width: 42, height: 42)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dictar Síntoma o Nota")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.white)
                        Text("Habla con naturalidad, la IA pulirá el texto")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "waveform")
                        .font(.system(size: 20))
                        .foregroundStyle(.msAccent)
                }
                .padding(14)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.msAccent.opacity(0.3), lineWidth: 1)
                )
            }

            // Botón 2: Generar Dossier para el Médico
            Button(action: exportDoctorPDF) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generar Dossier para mi Médico")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.white)
                        Text("PDF de 1 página con constantes, analíticas y preguntas")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    if isGeneratingPDF {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color.msAccent, Color.msSleep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.msAccent.opacity(0.3), radius: 10, y: 3)
            }
            .disabled(isGeneratingPDF)

            // Botón 3: Check-in diario de bienestar
            Button(action: { showCheckIn = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.msNutrition.opacity(0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: "face.smiling.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.msNutrition)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check-in de bienestar")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.white)
                        Text("¿Cómo te sientes hoy? 1 tap")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundStyle(.msNutrition)
                }
                .padding(14)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.msNutrition.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func exportDoctorPDF() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true

        // Construir los datos en el hilo principal (acceso a @State, rápido)
        let avgSleepHours = sleepData.map { Double($0.totalMinutes) / 60.0 }.average
        let currentProfile = profile ?? UserProfile(name: "Paciente")

        let reportData = MedicalReportExporter.FullClinicalReportData(
            patientProfile: currentProfile,
            periodDescription: "Últimas 2 semanas",
            generatedDate: Date(),
            activityAverage: (
                steps: Int(activityData.map(\.steps).average),
                calories: Int(activityData.map(\.activeCalories).average)
            ),
            cardioSummary: (
                restingHR: cardioData.compactMap(\.restingHeartRate).average,
                hrv: cardioData.compactMap(\.heartRateVariability).average
            ),
            sleepAverageHours: avgSleepHours,
            activeMedications: Array(medications.filter { $0.isCurrent }),
            recentSymptoms: Array(recentSymptoms.prefix(5)),
            recentLabMarkers: [],
            keyObservations: doctorPrep?.keyObservations ?? ["Constantes registradas periódicamente."],
            questionsForDoctor: doctorPrep?.questionsToAskDoctor ?? ["¿Cómo valora mi evolución general?"]
        )

        // Generación síncrona: el PDF es de 1 página (~50 ms, imperceptible).
        // NOTA: no usar Task.detached aquí — FullClinicalReportData contiene
        // modelos SwiftData (no Sendable) y MedicalReportExporter es @MainActor.
        // Con Swift 6 strict concurrency, el detached rompería la compilación.
        generatedPDFData = MedicalReportExporter.shared.generatePDF(data: reportData)
        isGeneratingPDF = false
        showShareSheet = true
    }

    // MARK: - Sección de Síntomas Recientes Dictados

    private var recentSymptomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .foregroundStyle(.msAccent)
                Text("Síntomas registrados")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            ForEach(recentSymptoms.prefix(3), id: \.id) { sym in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sym.symptomName)
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.msTextPrimary)
                        if let dictation = sym.rawDictation {
                            Text(dictation)
                                .font(.system(size: 11))
                                .foregroundStyle(.msTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(sym.timestamp.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(.msTextTertiary)
                }
                .padding(10)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Sección de Preparación de Consulta

    private func doctorPrepSection(_ prep: HealthAgent.DoctorVisitSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .foregroundStyle(.msAccent)
                Text("Preparación para tu próxima visita médica")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            Text(prep.executiveSummary)
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)

            if !prep.questionsToAskDoctor.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preguntas sugeridas para tu doctor:")
                        .font(.msCaption)
                        .foregroundStyle(.msAccent)

                    ForEach(prep.questionsToAskDoctor, id: \.self) { question in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.msAccent)
                            Text(question)
                                .font(.msBody)
                                .foregroundStyle(.msTextPrimary)
                        }
                    }
                }
                .padding(12)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Grid de métricas

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "FC en reposo",
                value: "\(Int(todayCardio?.restingHeartRate ?? 0))",
                unit: "bpm",
                icon: "heart.fill",
                color: .msCardio,
                trend: nil
            )

            MetricCard(
                title: "Variabilidad (HRV)",
                value: String(format: "%.0f", todayCardio?.heartRateVariability ?? 0),
                unit: "ms",
                icon: "waveform.path.ecg",
                color: .msLabs,
                trend: nil
            )

            MetricCard(
                title: "Sueño medio",
                value: String(format: "%.1f", Double(todaySleep?.totalMinutes ?? 0) / 60.0),
                unit: "horas",
                icon: "moon.stars.fill",
                color: .msSleep,
                trend: nil
            )

            MetricCard(
                title: "Pasos diarios",
                value: "\(todayActivity?.steps ?? 0)",
                unit: "pasos",
                icon: "figure.walk",
                color: .msNutrition,
                trend: nil
            )
        }
        // SEGURIDAD: redactar estas métricas en capturas de pantalla y App Switcher
        .privacySensitive()
    }

    // MARK: - Anillo de objetivo de descanso (HealthRing)

    private var sleepGoalRing: some View {
        HStack(spacing: 20) {
            HealthRing(
                progress: sleepProgress,
                lineWidth: 12,
                gradient: LinearGradient.msSleepGradient,
                icon: "moon.stars.fill"
            )
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text("Objetivo de descanso")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Text(String(format: "%.1f h / %.1f h", currentSleepHours, profile?.goalSleepHours ?? 7.5))
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextSecondary)
                HealthBadge(
                    label: sleepProgress >= 1 ? "Objetivo cumplido" : "En progreso",
                    status: sleepProgress >= 1 ? .good : .neutral
                )
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
        .privacySensitive()
    }

    private var currentSleepHours: Double {
        Double(todaySleep?.totalMinutes ?? 0) / 60.0
    }

    private var sleepProgress: Double {
        let goal = max(profile?.goalSleepHours ?? 7.5, 0.1)
        return min(currentSleepHours / goal, 1.0)
    }

    // MARK: - Gráfica de Sueño

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.msSleep)
                Text("Registro de Sueño — 7 días")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            Chart(sleepData, id: \.date) { day in
                BarMark(
                    x: .value("Día", day.date, unit: .day),
                    y: .value("Horas", Double(day.totalMinutes) / 60.0)
                )
                .foregroundStyle(LinearGradient.msSleepGradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(Color.msTextTertiary)
                        .font(.msCaption)
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Gráfica de FC

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.msCardio)
                Text("Frecuencia Cardíaca en Reposo")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            Chart(cardioData.filter { $0.restingHeartRate != nil }, id: \.date) { day in
                LineMark(
                    x: .value("Día", day.date, unit: .day),
                    y: .value("FC reposo", day.restingHeartRate ?? 0)
                )
                .foregroundStyle(Color.msCardio)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(Color.msTextTertiary).font(.msCaption)
                }
            }
            .frame(height: 100)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Carga de datos

    private func loadData() async {
        // 1. INSTANTÁNEO: usar el cache precargado durante el splash
        if healthKit.didPreload {
            activityData = healthKit.cachedActivity
            cardioData = healthKit.cachedCardio
            sleepData = healthKit.cachedSleep
            nutritionData = healthKit.cachedNutrition
        } else {
            // 2. Fallback: consultar directamente (si no hubo preload)
            async let activity = try? healthKit.fetchActivitySummary(for: 14)
            async let cardio = try? healthKit.fetchCardioSummary(for: 14)
            async let sleep = try? healthKit.fetchSleepSummary(for: 14)
            async let nutrition = try? healthKit.fetchNutritionSummary(for: 14)

            let (a, c, s, n) = await (activity, cardio, sleep, nutrition)
            withAnimation(.msSlow) {
                activityData = a ?? []
                cardioData = c ?? []
                sleepData = s ?? []
                nutritionData = n ?? []
            }
        }

        // 3. Recomendaciones seguras (datos vs. objetivos del perfil)
        recommendations = WellnessRecommendations.shared.generate(
            sleep: sleepData,
            cardio: cardioData,
            activity: activityData,
            nutrition: nutritionData,
            profile: profile
        )
    }
}

private extension [Double] {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private extension [Int] {
    var average: Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}

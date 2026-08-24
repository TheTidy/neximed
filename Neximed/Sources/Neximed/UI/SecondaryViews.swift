// Neximed — NutritionView.swift + LabsView.swift + TrendsView.swift
// Vistas de los módulos secundarios del MVP

import SwiftUI
import SwiftData
import PhotosUI
import Charts
import PDFKit

// ============================================================
// MARK: - NutritionView
// ============================================================

struct NutritionView: View {

    @State private var analyzer = FoodAnalyzer.shared
    @State private var healthKit = HealthKitManager.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var foodAnalysis: HealthAgent.FoodAnalysis?
    @State private var nutritionData: [NutritionSnapshot] = []
    @State private var showConfirmLog = false
    @State private var isLoading = false
    @State private var barcodeProduct: FoodAnalyzer.BarcodeProduct?
    @State private var isScanningBarcode = false
    @State private var showFoodLog = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {

                // MARK: Header
                sectionHeader(
                    icon: "fork.knife",
                    title: "Nutrición",
                    subtitle: "Registra y analiza tu alimentación",
                    color: .msNutrition
                )

                // MARK: Registro manual de comida
                Button { showFoodLog = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.msNutrition)
                        Text("Añadir comida manualmente")
                            .font(.msBodyEmphasized)
                            .foregroundStyle(.msTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.msTextTertiary)
                    }
                    .padding(14)
                    .background(Color.msSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.msNutrition.opacity(0.3), lineWidth: 1)
                    )
                }
                .sheet(isPresented: $showFoodLog) {
                    FoodLogView { name, kcal, protein, carbs, fat in
                        logManualMeal(name: name, kcal: kcal, protein: protein, carbs: carbs, fat: fat)
                    }
                }

                // MARK: Análisis de foto
                photoAnalysisCard

                // MARK: Resumen de hoy
                if let today = nutritionData.last {
                    todaySummaryCard(today)
                }

                // MARK: Distribución de macros (7 días)
                if nutritionData.count > 1 {
                    macroTrendChart
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .task {
            // Usar el cache precargado durante el splash (14 días) si está disponible
            if healthKit.didPreload {
                nutritionData = healthKit.cachedNutrition
            } else {
                nutritionData = (try? await healthKit.fetchNutritionSummary(for: 7)) ?? []
            }
        }
    }

    // MARK: - Tarjeta de análisis de foto

    private var photoAnalysisCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(.msNutrition)
                Text("Analizar plato con IA")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            // Área de imagen
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.msSurface)
                        .frame(height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.msNutrition.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )

                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.msNutrition.opacity(0.6))
                            Text("Toca para fotografiar tu plato")
                                .font(.msCaption)
                                .foregroundStyle(.msTextSecondary)
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        isLoading = true
                        foodAnalysis = try? await analyzer.analyzePhoto(image)
                        isLoading = false
                    }
                }
            }

            // Botón alternativo: escanear código de barras de un producto envasado
            Button(action: { isScanningBarcode = true }) {
                HStack {
                    if isScanningBarcode {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "barcode.viewfinder")
                    }
                    Text(isScanningBarcode ? "Escaneando..." : "Escanear código de barras")
                }
                .font(.msBodyEmphasized)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isScanningBarcode)
            .sheet(isPresented: $isScanningBarcode) {
                BarcodeScannerView { product in
                    barcodeProduct = product
                }
            }

            // Resultado del código de barras
            if let product = barcodeProduct {
                barcodeResultCard(product)
            }

            // Resultado del análisis
            if isLoading {
                HStack {
                    ProgressView().tint(.msNutrition)
                    Text("Analizando con IA...").font(.msBody).foregroundStyle(.msTextSecondary)
                }
            } else if let analysis = foodAnalysis {
                VStack(spacing: 12) {
                    Text(analysis.description)
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.msTextPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Grid de macros estimados
                    HStack(spacing: 0) {
                        MacroCell(value: Int(analysis.estimatedCalories), label: "kcal", color: .msActivity)
                        Divider().overlay(Color.msBorder).frame(height: 40)
                        MacroCell(value: Int(analysis.protein), label: "Prot (g)", color: .msNutrition)
                        Divider().overlay(Color.msBorder).frame(height: 40)
                        MacroCell(value: Int(analysis.carbs), label: "Carbos (g)", color: .msWarning)
                        Divider().overlay(Color.msBorder).frame(height: 40)
                        MacroCell(value: Int(analysis.fat), label: "Grasas (g)", color: .msLabs)
                    }
                    .background(Color.msSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Confianza del análisis
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.msTextTertiary)
                        Text("Confianza: \(Int(analysis.confidence * 100))% • Estimación aproximada")
                            .font(.system(size: 11))
                            .foregroundStyle(.msTextTertiary)
                        Spacer()
                    }

                    // Botón de registrar
                    Button(action: { Task { await logMeal(analysis) } }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Registrar en Apple Health")
                        }
                        .font(.msBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LinearGradient.msNutritionGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func logMeal(_ analysis: HealthAgent.FoodAnalysis) async {
        let meal = MealEntry(
            id: UUID(),
            timestamp: Date(),
            name: analysis.description,
            calories: analysis.estimatedCalories,
            protein: analysis.protein,
            carbs: analysis.carbs,
            fat: analysis.fat,
            imageData: capturedImage?.jpegData(compressionQuality: 0.5),
            source: .photoAI
        )
        try? await healthKit.logMeal(meal)
        // Actualizar datos
        nutritionData = (try? await healthKit.fetchNutritionSummary(for: 7)) ?? []
        foodAnalysis = nil
        capturedImage = nil
    }

    /// Registra una comida manual desde la base de datos curada (FoodLogView)
    private func logManualMeal(name: String, kcal: Double, protein: Double, carbs: Double, fat: Double) {
        let meal = MealEntry(
            id: UUID(),
            timestamp: Date(),
            name: name,
            calories: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            imageData: nil,
            source: .manual
        )
        modelContext.insert(meal)
        try? modelContext.save()

        // También a HealthKit para mantener la coherencia
        Task {
            try? await healthKit.logMeal(meal)
            nutritionData = (try? await healthKit.fetchNutritionSummary(for: 7)) ?? []
        }
    }

    // MARK: - Resumen de hoy

    private func todaySummaryCard(_ day: NutritionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen de hoy")
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)

            HStack(spacing: 0) {
                MacroCell(value: Int(day.totalCalories), label: "kcal", color: .msActivity)
                Divider().overlay(Color.msBorder).frame(height: 40)
                MacroCell(value: Int(day.protein), label: "Proteínas", color: .msNutrition)
                Divider().overlay(Color.msBorder).frame(height: 40)
                MacroCell(value: Int(day.carbohydrates), label: "Carbos", color: .msWarning)
                Divider().overlay(Color.msBorder).frame(height: 40)
                MacroCell(value: Int(day.fat), label: "Grasas", color: .msLabs)
            }
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Tendencia de macros

    private var macroTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proteínas — 7 días")
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)

            Chart(nutritionData, id: \.date) { day in
                BarMark(
                    x: .value("Día", day.date, unit: .day),
                    y: .value("Proteínas", day.protein)
                )
                .foregroundStyle(LinearGradient.msNutritionGradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(Color.msTextTertiary)
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .glassCard()
    }
}

struct MacroCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.msTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// ============================================================
// MARK: - LabsView
// ============================================================

struct LabsView: View {

    @State private var scanner = LabScanner.shared
    @State private var agent = HealthAgent.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var scannedResult: LabResult?
    @State private var interpretation: String = ""
    @State private var labHistory: [LabResult] = []
    @State private var isInterpreting = false
    @State private var isImportingPDF = false
    @State private var importedPDF: PDFDocument?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {

                sectionHeader(
                    icon: "testtube.2",
                    title: "Laboratorio",
                    subtitle: "Escanea y analiza tus analíticas",
                    color: .msLabs
                )

                // MARK: Escaner de analítica
                scanCard

                // MARK: Resultado del escáner
                if let result = scannedResult {
                    labResultCard(result)
                } else {
                    // Empty state con ilustración
                    EmptyStateCard(
                        image: "empty-labs",
                        title: "Sin analíticas todavía",
                        subtitle: "Escanea o importa tu primera analítica para ver tus biomarcadores organizados."
                    )
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var scanCard: some View {
        VStack(spacing: 14) {
            // Ilustración del escáner de biomarcadores
            Image("illustration-labs")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(0.9)

            HStack {
                Image(systemName: "doc.viewfinder.fill")
                    .foregroundStyle(.msLabs)
                Text("Escanear analítica")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            Text("Fotografía o importa tu analítica de laboratorio. El agente extraerá los valores automáticamente y los explicará en lenguaje sencillo.")
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Seleccionar imagen")
                }
                .font(.msBodyEmphasized)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.msLabs, Color.msAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        scannedResult = try? await scanner.scanPhoto(image)
                    }
                }
            }

            // Botón alternativo: importar PDF de analítica
            Button(action: { isImportingPDF = true }) {
                HStack {
                    Image(systemName: "doc.richtext.fill")
                    Text("Importar PDF de analítica")
                }
                .font(.msBodyEmphasized)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.msSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .fileImporter(
                isPresented: $isImportingPDF,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let doc = PDFDocument(url: url) {
                        Task {
                            scannedResult = try? await scanner.scanPDF(doc)
                        }
                    }
                case .failure:
                    break
                }
            }

            if scanner.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: scanner.scanProgress)
                        .tint(.msLabs)
                    Text("Procesando analítica... \(Int(scanner.scanProgress * 100))%")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func labResultCard(_ result: LabResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.msGood)
                Text("Resultados extraídos")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
                Text("\(result.markers.count) marcadores")
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
            }

            // Lista de marcadores
            ForEach(result.markers, id: \.id) { marker in
                LabMarkerRow(marker: marker)
            }

            // Botón de interpretación
            if interpretation.isEmpty {
                Button(action: { Task { await interpretResults(result) } }) {
                    HStack {
                        if isInterpreting {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isInterpreting ? "Interpretando..." : "Interpretar con IA")
                    }
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient.msAgentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isInterpreting)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile.fill")
                            .foregroundStyle(.msSleep)
                        Text("Interpretación del agente")
                            .font(.msHeadline)
                            .foregroundStyle(.msTextPrimary)
                    }
                    Text(interpretation)
                        .font(.msBody)
                        .foregroundStyle(.msTextSecondary)
                }
                .padding(12)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .glassCard()
        // SEGURIDAD: los valores de analíticas son datos médicos sensibles
        .privacySensitive()
    }

    private func interpretResults(_ result: LabResult) async {
        isInterpreting = true
        interpretation = await agent.interpretLabResults(result.markers, patientProfile: nil)
        isInterpreting = false
    }
}

struct LabMarkerRow: View {
    let marker: LabMarker

    var statusColor: Color {
        switch marker.status {
        case .normal:   return .msGood
        case .low:      return .msLabs
        case .high:     return .msWarning
        case .critical: return .msDanger
        }
    }

    var statusText: String {
        switch marker.status {
        case .normal:   return "Normal"
        case .low:      return "Bajo"
        case .high:     return "Alto"
        case .critical: return "Crítico"
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(marker.name)
                .font(.msBody)
                .foregroundStyle(.msTextPrimary)

            Spacer()

            Text("\(marker.value, specifier: "%.1f") \(marker.unit)")
                .font(.msBodyEmphasized)
                .foregroundStyle(.msTextPrimary)

            Text(statusText)
                .font(.msCaption)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// ============================================================
// MARK: - TrendsView
// ============================================================

struct TrendsView: View {

    @State private var healthKit = HealthKitManager.shared
    @State private var activityData: [ActivitySnapshot] = []
    @State private var cardioData: [CardioSnapshot] = []
    @State private var sleepData: [SleepSnapshot] = []
    @State private var correlations: [CorrelationResult] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {

                sectionHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Tendencias",
                    subtitle: "Patrones y correlaciones de tu salud",
                    color: .msActivity
                )

                // Correlación Sueño ↔ Pasos
                correlationCard

                // Patrones observacionales (correlaciones automáticas)
                CorrelationsView(results: correlations)

                // Seguimiento de peso
                WeightTrackingView()

                // Tendencia de pasos
                stepsChart

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .task {
            // Usar el cache precargado durante el splash si está disponible
            if healthKit.didPreload {
                activityData = healthKit.cachedActivity
                cardioData = healthKit.cachedCardio
                sleepData = healthKit.cachedSleep
            } else {
                async let a = try? healthKit.fetchActivitySummary(for: 14)
                async let c = try? healthKit.fetchCardioSummary(for: 14)
                async let s = try? healthKit.fetchSleepSummary(for: 14)
                let (act, card, sl) = await (a, c, s)
                activityData = act ?? []
                cardioData = card ?? []
                sleepData = sl ?? []
            }

            // Calcular correlaciones observacionales
            correlations = CorrelationAnalyzer.shared.analyze(
                sleep: sleepData,
                cardio: cardioData,
                activity: activityData
            )
        }
    }

    private var correlationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.msAccent)
                Text("Actividad — 14 días")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
            }

            Text("Evolución de pasos y calorías activas")
                .font(.msCaption)
                .foregroundStyle(.msTextSecondary)

            Chart(activityData, id: \.date) { day in
                LineMark(
                    x: .value("Fecha", day.date),
                    y: .value("Pasos", day.steps)
                )
                .foregroundStyle(Color.msNutrition)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month())
                        .foregroundStyle(Color.msTextTertiary)
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .glassCard()
    }

    private var stepsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV — 14 días")
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)

            Chart(cardioData.filter { $0.heartRateVariability != nil }, id: \.date) { day in
                AreaMark(
                    x: .value("Fecha", day.date),
                    y: .value("HRV", day.heartRateVariability ?? 0)
                )
                .foregroundStyle(LinearGradient(
                    colors: [Color.msLabs.opacity(0.4), Color.clear],
                    startPoint: .top, endPoint: .bottom
                ))

                LineMark(
                    x: .value("Fecha", day.date),
                    y: .value("HRV", day.heartRateVariability ?? 0)
                )
                .foregroundStyle(Color.msLabs)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month())
                        .foregroundStyle(Color.msTextTertiary)
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Helper compartido para headers de sección

func sectionHeader(icon: String, title: String, subtitle: String, color: Color) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.msTitle)
                .foregroundStyle(.msTextPrimary)
            Text(subtitle)
                .font(.msCaption)
                .foregroundStyle(.msTextSecondary)
        }
        Spacer()
    }
}


// ============================================================
// MARK: - BarcodeScannerView (escáner de código de barras)
// ============================================================

struct BarcodeScannerView: View {
    let onFound: (FoodAnalyzer.BarcodeProduct) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.msSurface)
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.msAccent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            )
                        VStack(spacing: 8) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.msAccent.opacity(0.7))
                            Text("Selecciona una foto del código de barras")
                                .font(.msBody)
                                .foregroundStyle(.msTextSecondary)
                        }
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let product = try? await FoodAnalyzer.shared.scanBarcode(from: image) {
                            onFound(product)
                            dismiss()
                        }
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(Color.msBackground)
            .navigationTitle("Escanear código")
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

// MARK: - Tarjeta de resultado del código de barras

struct BarcodeResultCard: View {
    let product: FoodAnalyzer.BarcodeProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "barcode")
                    .foregroundStyle(.msNutrition)
                Text("Producto detectado")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                Spacer()
            }

            if let name = product.name {
                Text(name)
                    .font(.msBodyEmphasized)
                    .foregroundStyle(.msTextPrimary)
            }
            if let brand = product.brand {
                Text(brand)
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
            }

            HStack(spacing: 0) {
                MacroCell(value: Int(product.caloriesPer100g ?? 0), label: "kcal/100g", color: .msActivity)
                Divider().overlay(Color.msBorder).frame(height: 40)
                MacroCell(value: Int(product.proteinPer100g ?? 0), label: "Prot (g)", color: .msNutrition)
                Divider().overlay(Color.msBorder).frame(height: 40)
                MacroCell(value: Int(product.carbsPer100g ?? 0), label: "Carbos (g)", color: .msWarning)
                Divider().overlay(Color.msBorder).frame(height: 40)
                MacroCell(value: Int(product.fatPer100g ?? 0), label: "Grasas (g)", color: .msLabs)
            }
            .background(Color.msSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Helper para la tarjeta de código de barras dentro de NutritionView

private extension NutritionView {
    func barcodeResultCard(_ product: FoodAnalyzer.BarcodeProduct) -> some View {
        BarcodeResultCard(product: product)
    }
}



// ============================================================
// MARK: - EmptyStateCard (estado vacío con ilustración)
// ============================================================

struct EmptyStateCard: View {
    let image: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .opacity(0.9)

            Text(title)
                .font(.msHeadline)
                .foregroundStyle(.msTextPrimary)

            Text(subtitle)
                .font(.msBody)
                .foregroundStyle(.msTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }
}


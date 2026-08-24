// Neximed — DesignSystem.swift
// Sistema de diseño completo: colores, tipografía, componentes y animaciones

import SwiftUI

// MARK: - Paleta de Colores

extension Color {

    // Inicializador desde hex (formato 0xRRGGBB)
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    // Tokens oficiales — Deep Slate Void & Obsidian Glass (fondo)
    static let msBackground       = Color(hex: 0x0D1117)   // Deep Slate Void
    static let msSurface          = Color(hex: 0x161B22)   // Obsidian Glass
    static let msSurfaceElevated  = Color(hex: 0x21262D)   // Elevated Glass
    static let msBorder           = Color(hex: 0x30363D)   // Subtle Cyan Border

    // Acentos de marca — Nexus Cyan & Vagus Violet
    static let msAccent           = Color(hex: 0x00D2FF)   // Nexus Cyan (acento primario, voz e IA)
    static let msAccentSecondary  = Color(hex: 0x8A2BE2)   // Vagus Violet (inteligencia y descanso)

    // Categorías de salud
    static let msCardio           = Color(hex: 0xFF5E62)   // Pulse Coral (frecuencia cardíaca)
    static let msSleep            = Color(hex: 0x8A2BE2)   // Vagus Violet (descanso)
    static let msNutrition        = Color(hex: 0x38EF7D)   // Vital Lime (nutrición)
    static let msActivity         = Color(hex: 0xFF9F43)   // Energía naranja (actividad)
    static let msLabs             = Color(hex: 0x0099FF)   // Clinical Azure (analíticas)

    // Semáforo clínico
    static let msGood             = Color(hex: 0x2ECC71)   // Safe Emerald (en rango)
    static let msWarning          = Color(hex: 0xFFB020)   // Ámbar (precaución)
    static let msDanger           = Color(hex: 0xFF3B30)   // Rojo (fuera de rango)

    // Texto
    static let msTextPrimary    = Color.white
    static let msTextSecondary  = Color.white.opacity(0.65)
    static let msTextTertiary   = Color.white.opacity(0.40)
}

// MARK: - Tipografía

extension Font {
    // Display — para títulos grandes y métricas
    static let msDisplay        = Font.system(size: 48, weight: .bold, design: .rounded)
    static let msDisplayMedium  = Font.system(size: 34, weight: .bold, design: .rounded)
    static let msTitle          = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let msHeadline       = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let msBody           = Font.system(size: 15, weight: .regular, design: .default)
    static let msBodyEmphasized = Font.system(size: 15, weight: .medium, design: .default)
    static let msCaption        = Font.system(size: 12, weight: .medium, design: .rounded)
    static let msMetric         = Font.system(size: 38, weight: .heavy, design: .rounded)
}

// MARK: - Gradientes

extension LinearGradient {
    static let msAgentGradient = LinearGradient(
        colors: [Color.msAccent, Color.msSleep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let msCardioGradient = LinearGradient(
        colors: [Color.msCardio, Color.msCardio.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let msSleepGradient = LinearGradient(
        colors: [Color.msSleep, Color(hex: 0x5B21B6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let msNutritionGradient = LinearGradient(
        colors: [Color.msNutrition, Color.msActivity],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let msBackgroundGradient = LinearGradient(
        colors: [Color.msBackground, Color(hex: 0x05080D)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Modificadores de Vista

struct GlassCard: ViewModifier {
    var isProminent: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.msSurface.opacity(isProminent ? 0.95 : 0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.msBorder.opacity(0.4), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
            )
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    var color: Color

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func glassCard(isProminent: Bool = false) -> some View {
        modifier(GlassCard(isProminent: isProminent))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    func pulseEffect(color: Color) -> some View {
        modifier(PulseModifier(color: color))
    }
}

// MARK: - Componentes Reutilizables

// Tarjeta de métrica de salud
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: TrendDirection?

    enum TrendDirection {
        case up, down, stable
        var icon: String {
            switch self {
            case .up:     return "arrow.up.right"
            case .down:   return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        var color: Color {
            switch self {
            case .up:     return .msGood
            case .down:   return .msDanger
            case .stable: return .msTextSecondary
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
                Spacer()
                if let trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trend.color)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.msMetric)
                    .foregroundStyle(.msTextPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.msCaption)
                    .foregroundStyle(.msTextSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.msSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// Badge de estado de salud (semáforo)
struct HealthBadge: View {
    let label: String
    let status: HealthStatus

    enum HealthStatus {
        case good, warning, danger, neutral

        var color: Color {
            switch self {
            case .good:    return .msGood
            case .warning: return .msWarning
            case .danger:  return .msDanger
            case .neutral: return .msTextSecondary
            }
        }
        var icon: String {
            switch self {
            case .good:    return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger:  return "xmark.circle.fill"
            case .neutral: return "minus.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(status.color)
            Text(label)
                .font(.msCaption)
                .foregroundStyle(.msTextSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
                .overlay(Capsule().stroke(status.color.opacity(0.3), lineWidth: 0.5))
        )
    }
}

// Barra de progreso circular estilo Apple Rings
struct HealthRing: View {
    let progress: Double  // 0 a 1
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let icon: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.msBorder.opacity(0.3), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 1.2, bounce: 0.3), value: progress)

            Image(systemName: icon)
                .font(.system(size: lineWidth * 0.8, weight: .semibold))
                .foregroundStyle(gradient)
        }
    }
}

// Burbuja de chat del agente
struct AgentBubble: View {
    let message: String
    let isUser: Bool
    let isLoading: Bool

    @State private var dotOpacity = [1.0, 0.4, 0.4]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                // Avatar del agente
                ZStack {
                    Circle()
                        .fill(LinearGradient.msAgentGradient)
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            if isLoading {
                // Indicador de escritura
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.msAccent)
                            .frame(width: 6, height: 6)
                            .opacity(dotOpacity[i])
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.15),
                                value: dotOpacity[i]
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.msSurface)
                )
                .onAppear {
                    dotOpacity = [0.4, 0.4, 1.0]
                }
            } else {
                Text(message)
                    .font(.msBody)
                    .foregroundStyle(.msTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser ? Color.msAccent.opacity(0.85) : Color.msSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        isUser ? Color.clear : Color.msBorder.opacity(0.3),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            }

            if isUser { Spacer() }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

// MARK: - Animaciones

extension Animation {
    static let msSpring = Animation.spring(duration: 0.5, bounce: 0.3)
    static let msEase = Animation.easeInOut(duration: 0.3)
    static let msSlow = Animation.easeInOut(duration: 0.8)
}

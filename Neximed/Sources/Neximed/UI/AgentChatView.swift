// Neximed — AgentChatView.swift
// Interfaz conversacional con el agente de IA de salud

import SwiftUI
import SwiftData
import PhotosUI

struct AgentChatView: View {

    @State private var agent = HealthAgent.shared
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ChatMessage.timestamp, order: .forward) private var messages: [ChatMessage]
    @Query private var profiles: [UserProfile]

    @State private var inputText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingPhotoPicker = false
    @State private var attachedImage: UIImage?
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var showSuggestions = true

    private let suggestions = [
        "¿Cómo ha sido mi sueño esta semana?",
        "Analiza mi frecuencia cardíaca",
        "¿Cómo están mis proteínas?",
        "Dame un resumen de mi salud",
        "¿Debo preocuparme por algo?",
        "Qué debería mejorar esta semana",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            agentHeader

            Divider()
                .overlay(Color.msBorder)

            // Mensajes
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            emptyState
                        }

                        ForEach(messages, id: \.id) { msg in
                            AgentBubble(
                                message: msg.content,
                                isUser: msg.role == .user,
                                isLoading: false
                            )
                            .id(msg.id)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: msg.role == .user ? .trailing : .leading).combined(with: .opacity))
                            // SEGURIDAD: las conversaciones pueden contener datos de salud
                            .privacySensitive()
                        }

                        // Burbuja de "escribiendo..."
                        if agent.isThinking {
                            AgentBubble(message: "", isUser: false, isLoading: true)
                                .padding(.horizontal, 16)
                                .id("thinking")
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollProxy = proxy }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: agent.isThinking) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            // Sugerencias rápidas (solo si no hay mensajes)
            if messages.isEmpty || showSuggestions {
                suggestionsBar
            }

            // Input bar
            inputBar
        }
        .background(Color.clear)
        .navigationBarHidden(true)
    }

    // MARK: - Header del Agente

    private var agentHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient.msAgentGradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.msAccent.opacity(0.3), radius: 8)
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .pulseEffect(color: .msAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Neximed")
                    .font(.msHeadline)
                    .foregroundStyle(.msTextPrimary)
                HStack(spacing: 4) {
                    Circle().fill(Color.msGood).frame(width: 6, height: 6)
                    Text(agent.isThinking ? "Analizando..." : "Agente activo • On-device")
                        .font(.msCaption)
                        .foregroundStyle(.msTextSecondary)
                }
            }
            Spacer()

            // Botón de nueva conversación
            Button(action: clearChat) {
                Image(systemName: "plus.bubble.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.msTextSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Estado vacío

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(LinearGradient.msAgentGradient.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(LinearGradient.msAgentGradient)
            }

            VStack(spacing: 8) {
                Text("Hola, \(profiles.first?.name ?? "")! 👋")
                    .font(.msTitle)
                    .foregroundStyle(.msTextPrimary)

                Text("Soy tu agente de salud personal. Analizo tus datos de Apple Health y Apple Watch para ayudarte a entender tu cuerpo. ¿En qué puedo ayudarte hoy?")
                    .font(.msBody)
                    .foregroundStyle(.msTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Sugerencias rápidas

    private var suggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { sendMessage(suggestion) }) {
                        Text(suggestion)
                            .font(.msCaption)
                            .foregroundStyle(.msAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.msAccent.opacity(0.12))
                                    .overlay(Capsule().stroke(Color.msAccent.opacity(0.3), lineWidth: 0.5))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.msBorder.opacity(0.5))

            HStack(spacing: 10) {
                // Botón de adjuntar foto
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(.msTextSecondary)
                        .frame(width: 36, height: 36)
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            attachedImage = image
                        }
                    }
                }

                // Campo de texto
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Pregunta algo sobre tu salud...")
                            .font(.msBody)
                            .foregroundStyle(.msTextTertiary)
                    }

                    TextField("", text: $inputText, axis: .vertical)
                        .font(.msBody)
                        .foregroundStyle(.msTextPrimary)
                        .lineLimit(4)
                        .submitLabel(.send)
                        .onSubmit { sendCurrentMessage() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.msSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Botón de enviar
                Button(action: sendCurrentMessage) {
                    Image(systemName: inputText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(inputText.isEmpty ? Color.msTextSecondary : Color.msAccent)
                        .animation(.msSpring, value: inputText.isEmpty)
                }
                .disabled(agent.isThinking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
        }
        .background(Color.msBackground.opacity(0.95))
    }

    // MARK: - Acciones

    private func sendCurrentMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty || attachedImage != nil else { return }
        let text = inputText
        inputText = ""
        sendMessage(text)
    }

    private func sendMessage(_ text: String) {
        showSuggestions = false

        // Guardar mensaje del usuario
        let userMsg = ChatMessage(role: .user, content: text)
        modelContext.insert(userMsg)
        try? modelContext.save()

        Task {
            // Obtener respuesta del agente
            let response: String

            if let image = attachedImage {
                // Si hay imagen, analizarla primero
                let analysis = await agent.analyzeFoodPhoto(image.jpegData(compressionQuality: 0.7) ?? Data())
                let contextMsg = "\(text)\n\n[Análisis de imagen: \(analysis.description), ~\(Int(analysis.estimatedCalories)) kcal, \(Int(analysis.protein))g proteína, \(Int(analysis.carbs))g carbos, \(Int(analysis.fat))g grasa]"
                response = await agent.sendMessage(contextMsg)
                attachedImage = nil
            } else {
                response = await agent.sendMessage(text)
            }

            // Guardar respuesta del agente
            await MainActor.run {
                let agentMsg = ChatMessage(role: .agent, content: response)
                modelContext.insert(agentMsg)
                try? modelContext.save()
            }
        }
    }

    private func clearChat() {
        for msg in messages {
            modelContext.delete(msg)
        }
        showSuggestions = true
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.msEase) {
            if agent.isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    AgentChatView()
        .modelContainer(for: [ChatMessage.self, UserProfile.self], inMemory: true)
        .preferredColorScheme(.dark)
        .background(Color.msBackground)
}

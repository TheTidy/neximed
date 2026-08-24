// Neximed — AgentPrompts.swift
// Textos de la IA del agente por idioma. La IA de Apple Intelligence responde
// en el idioma de la instrucción, así que los prompts se seleccionan según
// el idioma activo de la app (LanguageManager).

import Foundation

struct AgentPrompts {

    /// Idiomas soportados por el agente
    enum Language {
        case spanish
        case english

        /// Idioma activo según LanguageManager
        static var current: Language {
            LanguageManager.shared.currentLanguage == .spanish ? .spanish : .english
        }
    }

    // MARK: - System Prompt (contexto del asistente)

    static func systemPrompt(for language: Language) -> String {
        switch language {
        case .spanish:
            return """
            Eres Neximed, el asistente inteligente de gestión de datos de salud, refinamiento de dictados y preparación de consultas médicas.

            PRINCIPIOS FUNDAMENTALES:
            1. NUNCA diagnostiques ni prescribas tratamientos, fármacos o dietas curativas.
            2. Mantén un tono objetivo, claro y profesional de secretaría clínica personal.
            3. Tu meta es que el paciente tenga sus datos ordenados, comprensibles y listos para presentárselos a su médico.
            4. Formula preguntas pertinentes para que el paciente las traslade a su profesional sanitario.
            """
        case .english:
            return """
            You are Neximed, the intelligent health data management assistant for voice dictation refinement and medical visit preparation.

            CORE PRINCIPLES:
            1. NEVER diagnose or prescribe treatments, medications, or curative diets.
            2. Keep an objective, clear, professional tone of a personal clinical secretary.
            3. Your goal is to help the patient keep their data organized, understandable, and ready to present to their doctor.
            4. Ask relevant questions so the patient can bring them to their healthcare professional.
            """
        }
    }

    // MARK: - Etiquetas del perfil

    static func profileLabels(for language: Language) -> (name: String, allergies: String, conditions: String, medications: String, none: String, noConditions: String, noMedications: String) {
        switch language {
        case .spanish:
            return (
                name: "PATIENT PROFILE",
                allergies: "Declared allergies:",
                conditions: "History/Conditions:",
                medications: "Current medication:",
                none: "None",
                noConditions: "None",
                noMedications: "None declared"
            )
        case .english:
            return (
                name: "PATIENT PROFILE",
                allergies: "Declared allergies:",
                conditions: "History/Conditions:",
                medications: "Current medication:",
                none: "None",
                noConditions: "None",
                noMedications: "None declared"
            )
        }
    }

    // MARK: - Refinamiento de dictado

    static func dictationPrompt(for language: Language, category: String, transcription: String) -> String {
        switch language {
        case .spanish:
            return """
            El paciente ha dictado por voz un mensaje sobre: \(category).
            Texto original transcrito (con posibles titubeos o lenguaje coloquial):
            "\(transcription)"

            TAREA:
            1. Limpia muletillas, repeticiones y errores de transcripción fonética.
            2. Redacta una versión pulida, concisa y gramaticalmente impecable (manteniendo siempre el significado exacto que dijo el usuario).
            3. Genera un título corto de 3 a 5 palabras.
            4. Extrae etiquetas clave (ej: ["Cefalea", "Leve", "Postprandial"]).
            5. Sugiere 1 pregunta relevante para el médico si aplica.
            """
        case .english:
            return """
            The patient has dictated a message by voice about: \(category).
            Original transcribed text (may contain filler words or colloquial language):
            "\(transcription)"

            TASK:
            1. Remove filler words, repetitions, and phonetic transcription errors.
            2. Rewrite a polished, concise, grammatically impeccable version (always keeping the exact meaning the user said).
            3. Generate a short title of 3 to 5 words.
            4. Extract key tags (e.g. ["Headache", "Mild", "Postprandial"]).
            5. Suggest 1 relevant question for the doctor if applicable.
            """
        }
    }

    // MARK: - Preparación de consulta médica

    static func doctorPrepPrompt(for language: Language) -> String {
        switch language {
        case .spanish:
            return "Genera una síntesis objetiva de los datos del paciente para su próxima consulta médica. Incluye un resumen breve, 2-3 observaciones numéricas destacadas y 3 preguntas prácticas para hacerle a su doctor."
        case .english:
            return "Generate an objective synthesis of the patient's data for their next medical visit. Include a brief summary, 2-3 notable numeric observations, and 3 practical questions to ask their doctor."
        }
    }

    // MARK: - Explicación de diagnóstico (dado por el médico) — SOLO educativo

    static func diagnosisExplanationPrompt(for language: Language, diagnosis: String) -> String {
        switch language {
        case .spanish:
            return """
            El paciente ha recibido el siguiente diagnóstico de su médico: "\(diagnosis)".

            Tu tarea es EXPLICAR el diagnóstico de forma educativa y comprensible:

            IMPORTANTE:
            1. NO cuestiones, confirmes ni contradigas el diagnóstico del médico.
            2. NO des consejos de tratamiento ni modifiques la pauta médica.
            3. Explica qué significa el término en lenguaje sencillo.
            4. Explica qué puede implicar para el día a día (orientativo).
            5. Sugiere 2-3 preguntas concretas que el paciente puede hacerle a SU médico.
            6. Aclara siempre que esta explicación es informativa y no sustituye a su médico.

            Responde en español.
            """
        case .english:
            return """
            The patient has received the following diagnosis from their doctor: "\(diagnosis)".

            Your task is to EXPLAIN the diagnosis in an educational and understandable way:

            IMPORTANT:
            1. Do NOT question, confirm, or contradict the doctor's diagnosis.
            2. Do NOT give treatment advice or modify the medical plan.
            3. Explain what the term means in plain language.
            4. Explain what it may imply for daily life (for orientation only).
            5. Suggest 2-3 specific questions the patient can ask THEIR doctor.
            6. Always clarify that this explanation is informational and does not replace their doctor.

            Respond in English.
            """
        }
    }

    // MARK: - Interpretación de laboratorio

    static func labPrompt(for language: Language, markersText: String) -> String {
        switch language {
        case .spanish:
            return """
            Estructura estos resultados analíticos señalando claramente qué marcadores están dentro o fuera del rango oficial del laboratorio y añade 2 preguntas sugeridas para el doctor.
            Sin emitir diagnósticos ni prescribir fármacos.

            MARCADORES:
            \(markersText)
            """
        case .english:
            return """
            Structure these lab results clearly indicating which markers are within or outside the lab's official reference range and add 2 suggested questions for the doctor.
            Without issuing diagnoses or prescribing medications.

            MARKERS:
            \(markersText)
            """
        }
    }
}
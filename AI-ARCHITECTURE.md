# 🤖 Neximed — Arquitectura Técnica de la IA (detallada)

> Documento de referencia **exacto** para implementar y verificar la capa de IA sin errores.
> Basado en fuentes oficiales de Apple (WWDC25 Sessions 286 y 301 + Apple Developer Documentation).
> Última verificación: sesión de investigación con fuentes oficiales.
> **Actualización v2**: punto abierto 3 resuelto (interpretLabResults ahora usa esquema @Generable verificado).

---

## 1. Vision general del sistema de IA

Neximed tiene **4 puntos de contacto con IA**, todos 100% on-device a través del framework **FoundationModels** (Apple Intelligence):

- 1. Dictado → Refinamiento  (refineAndStructureDictation)
- 2. Chat asistente general   (sendMessage)
- 3. Preparación de consulta médica (generateDoctorVisitPrep)
- 4. Interpretación de analíticas (interpretLabResults)
- 5. Análisis de foto de comida → PENDIENTE de validar (ver seccion 8)

**Principio rector**: cada función tiene un **fallback determinista** que se activa
cuando el dispositivo no soporta Apple Intelligence (iPhone anterior a 15 Pro,
iPad sin Apple Silicon, región sin soporte, o error de sesión).


---

## 2. APIs exactas y verificación

### 2.1 Sesión — LanguageModelSession

``````swift
import FoundationModels

// FIRMA CONFIRMADA por Apple:
// init(model: LanguageModel, tools: [any Tool], instructions: Instructions)
//   → tools e instructions tienen valores por defecto
let session = LanguageModelSession(
    model: SystemLanguageModel.default,   // clase confirmada
    instructions: Instructions(systemPrompt)
)
``````

| Símbolo | Confirmado | Fuente |
|---------|-----------|--------|
| LanguageModelSession.init(model:tools:instructions:) | OK | https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:) |
| SystemLanguageModel | OK | https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel |
| Instructions | OK | https://developer.apple.com/documentation/foundationmodels/instructions |
| Prompt | OK | https://developer.apple.com/documentation/foundationmodels/prompt |

### 2.2 Respuesta — respond

``````swift
// FIRMA CONFIRMADA (los parámetros extra tienen valores por defecto):
// respond(to: Prompt, generating: T.Type, includeSchemaInPrompt: Bool, options: ...)
let response = try await session.respond(to: Prompt(prompt), generating: MiSchema.self)
let resultado = response.content    // patrón canónico WWDC25
``````

| Firma | Confirmado | Fuente |
|-------|-----------|--------|
| respond(to:generating:includeSchemaInPrompt:options:) | OK | https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:generating:includeschemainprompt:options:) |
| respond(generating:options:contextOptions:metadata:prompt:) | OK (variante) | https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(generating:options:contextoptions:metadata:prompt:) |

### 2.3 Generación estructurada — macros @Generable y @Guide

``````swift
// CONFIRMADO en WWDC25 (sesiones 286 y 301)
@Generable
struct MiSchema {
    @Guide(description: "Descripción en lenguaje natural de lo que el modelo debe generar.")
    var campo: String
}
``````

El macro @Generable sintetiza la conformidad con el protocolo de esquema;
@Guide proporciona instrucciones al modelo por campo. Solo disponibles con
FoundationModels → deben ir envueltos en #if canImport(FoundationModels).

### 2.4 Disponibilidad y compilación

``````swift
#if canImport(FoundationModels)
import FoundationModels
#endif

// En cada uso:
if #available(iOS 26.0, macOS 26.0, *) {
    // usar LanguageModelSession
}
// Fuera del if: fallback determinista
``````

**Regla de oro**: *ninguna* referencia a FoundationModels puede quedar fuera
del #if canImport + if #available, o el build fallará en iOS 17/18.


---

## 3. Cómo funciona cada función de IA (flujo exacto)

### 3.1 refineAndStructureDictation(_:category:)

**Objetivo**: convertir dictado bruto → texto pulido + título + etiquetas + pregunta para el doctor.

Voz → SFSpeechRecognizer (on-device, es-ES) → rawTranscript
   → HealthAgent.refineAndStructureDictation(raw, category)
      → ¿canImport + #available + session existe? → NO → fallback local (4.1)
      → SÍ: prompt = TAREA (limpiar muletillas, redactar, título 3-5 palabras,
              etiquetas, 1 pregunta médica) + contexto del texto bruto
      → session.respond(to: Prompt(prompt), generating: RefinedDictationSchema.self)
        → response.content → RefinedDictationResult (estructurado)
        → si lanza error → fallback local (4.1)

**Prompt exacto** (en HealthAgent.swift):
El paciente ha dictado por voz un mensaje sobre: <categoría>.
Texto original transcrito (con posibles titubeos o lenguaje coloquial):
"<texto>"

TAREA:
1. Limpia muletillas, repeticiones y errores de transcripción fonética.
2. Redacta una versión pulida, concisa y gramaticalmente impecable (manteniendo siempre el significado exacto que dijo el usuario).
3. Genera un título corto de 3 a 5 palabras.
4. Extrae etiquetas clave (ej: ["Cefalea", "Leve", "Postprandial"]).
5. Sugiere 1 pregunta relevante para el médico si aplica.

### 3.2 sendMessage(_:)

**Objetivo**: responder preguntas generales sobre los datos de salud.

usuario escribe → ChatMessage(role: .user) guardado en SwiftData
   → HealthAgent.sendMessage(text)
      → ¿IA disponible? → NO → localResponse(for:) (4.2): detecta tema por
             palabras clave (sueño/corazón/pasos/proteínas/resumen) y responde
             con datos REALES de HealthKit (buildHealthContext)
      → SÍ: session.respond(to: Prompt(text), generating: AgentResponseSchema.self)
        → response.content.message → ChatMessage(role: .agent)
        → si error → localResponse(for:)

### 3.3 generateDoctorVisitPrep()

**Objetivo**: síntesis objetiva para la consulta médica (resumen + observaciones + preguntas).

DashboardView .task → HealthAgent.generateDoctorVisitPrep()
   → ¿IA? → NO → localDoctorPrep() (4.3): construye DoctorVisitSummary
          con medias REALES de HealthKit (FC reposo, HRV, sueño, pasos)
          + 3 preguntas estándar
   → SÍ: prompt fijo → session.respond(to:generating: DoctorVisitSummarySchema.self)
     → si error → localDoctorPrep()

### 3.4 interpretLabResults(_:patientProfile:)

**Objetivo**: explicar una analítica marcando en/fuera de rango (sin diagnosticar).

LabsView → agent.interpretLabResults(result.markers, patientProfile: nil)
   → ¿IA? → NO → localLabInterpretation(markers) (4.4):
          cuenta en/fuera de rango, lista los fuera de rango, aclara que es informativo
   → SÍ: prompt con marcadores → session.respond(to: Prompt(prompt),
          generating: LabInterpretationSchema.self)   ← ESQUEMA ESTRUCTURADO (v2)
     → response.content: explanation + outOfRangeMarkers + questionsForDoctor
     → se compone el texto final
     → si error → localLabInterpretation(markers)


---

## 4. Fallbacks deterministas (sin Apple Intelligence)

Toda la capa "Modo Básico" garantiza que la app **funciona al 100%** sin IA.
Datos reales de HealthKit + heurísticas locales.

### 4.1 localRefineDictation
1. Elimina muletillas: ["eh", "o sea", "osea", "tipo", "bueno", "pues", "este", "mmm", "ajá", "ya sabes"]
2. Colapsa espacios múltiples
3. Capitaliza primera letra + añade punto final
4. Título = primeras 3 palabras significativas
5. Etiquetas por diccionario: síntomas (cefalea, mareo, náusea, fatiga, fiebre, tos, dolor, insomnio, ansiedad), intensidad (leve/moderada/intensa), contexto (mañana/tarde/noche/postprandial)
6. Pregunta según categoría (symptom/doctorNote/medication/general)

### 4.2 localResponse(for:)
Detección por palabras clave del tema de la pregunta y respuesta con medias reales:
- sueño → horas/noche + min de sueño profundo
- corazón/FC → bpm reposo + HRV
- pasos/actividad → pasos diarios vs objetivo
- proteínas/nutrición → kcal + proteína
- resumen → resumen de la semana
- otro → mensaje genérico + sugerencias

### 4.3 localDoctorPrep()
Construye DoctorVisitSummary con: FC reposo media, HRV media, sueño medio,
pasos medios + 3 preguntas estándar para el médico.

### 4.4 localLabInterpretation(markers)
Conteo de marcadores en/fuera de rango + lista de los fuera de rango +
aviso legal informativo.


---

## 5. Requisitos de plataforma (verificados)

| Requisito | Valor |
|-----------|-------|
| Deployment target | iOS 17.0 (para máxima cobertura) |
| IA on-device | iOS 26+ + dispositivo con Apple Intelligence (iPhone 15 Pro o posterior; iPads con M1 o posterior) |
| Entitlement | Ninguno — FoundationModels no requiere entitlement de app. `com.apple.developer.foundation-models` no es un entitlement real (confirmado por Xcode al firmar: "not found... not a valid entitlement"); el acceso se controla en runtime por capacidad del dispositivo |
| Regional | Apple Intelligence requiere región e idioma soportados (Apple lo amplía progresivamente) |
| Compilación | Xcode 26+ con SDK iOS 26 (para que canImport(FoundationModels) sea true) |
| Simulador | FoundationModels NO disponible en simulador → probar en dispositivo físico |

**Implicación**: en España/idioma español, la disponibilidad de Apple
Intelligence puede ser limitada → el **fallback determinista es la experiencia
principal de muchos usuarios**. La app debe verse completa y útil en Modo Básico.


---

## 6. APIs de conexión (todas las del proyecto, con fuentes)

| API | Uso en Neximed | Fuente oficial |
|-----|----------------|----------------|
| FoundationModels | IA on-device (sesión, prompts, @Generable) | https://developer.apple.com/documentation/FoundationModels |
| HealthKit | Constantes, sueño, nutrición, actividad | https://developer.apple.com/documentation/HealthKit |
| HKStatisticsCollectionQuery | Agregación diaria de métricas | https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery |
| SFSpeechRecognizer | Dictado 100% on-device (es-ES) | https://developer.apple.com/documentation/speech/sfspeechrecognizer |
| AVAudioEngine | Captura de audio + niveles para la onda | https://developer.apple.com/documentation/avfaudio/avaudioengine |
| Vision (VNRecognizeTextRequest) | OCR de analíticas y etiquetas nutricionales | https://developer.apple.com/documentation/vision/vnrecognizetextrequest |
| PDFKit | Extracción de texto de PDFs de analíticas | https://developer.apple.com/documentation/pdfkit |
| SwiftData | Persistencia local (privacidad zero-knowledge) | https://developer.apple.com/documentation/swiftdata |
| Charts | Gráficas de sueño, FC, macros, HRV | https://developer.apple.com/documentation/charts |
| AppIntents | Siri: consultar salud, registrar comida, resumen | https://developer.apple.com/documentation/appintents |
| PhotosUI | Selección de fotos para OCR/análisis | https://developer.apple.com/documentation/photokit/photospicker |
| UIActivityViewController | Compartir el Dossier PDF | https://developer.apple.com/documentation/uikit/uiactivityviewcontroller |
| Open Food Facts API | Búsqueda de productos por código de barras (opcional, con consentimiento) | https://world.openfoodfacts.org/data |

## 7. Checklist de verificación en Xcode (cuando tengas tu Mac)

- [ ] import FoundationModels solo dentro de #if canImport
- [ ] Toda llamada a session dentro de if #available(iOS 26.0, *)
- [ ] LanguageModelSession(model: SystemLanguageModel.default, instructions: Instructions(...))
      → si SystemLanguageModel.default diera error, usar SystemLanguageModel() (patrón WWDC26)
- [ ] session.respond(to: Prompt(...), generating: MiSchema.self) → response.content
- [ ] Los structs @Generable nombrados *Schema dentro del #if (no chocan con los planos)
- [ ] Los structs planos (RefinedDictationResult, etc.) fuera del #if (los usa la UI siempre)
- [x] analyzeFoodPhoto: confirmado que FoundationModels no soporta imágenes (ver 8) — fallback de confianza 0 es el comportamiento final
- [x] Sin entitlement de FoundationModels en el target (no existe; ver §5)
- [ ] Build con Xcode 26, deploy target 17.0 → probar en iPhone 15 Pro+ (IA) y iPhone 13 (Modo Básico)

## 8. Puntos abiertos — validados con build real (Xcode 26 / iOS 26.5 SDK, 2026-08-24)

| # | Punto | Estado | Conclusión |
|---|-------|--------|--------|
| 1 | SystemLanguageModel.default vs SystemLanguageModel() | ✅ RESUELTO | `SystemLanguageModel.default` compila (HealthAgent.swift:157). No hace falta cambiar a `SystemLanguageModel()`. |
| 2 | analyzeFoodPhoto con imagen real | ✅ RESUELTO — no es viable | Inspeccionado el `.swiftinterface` de `FoundationModels.framework` (iOS 26.5 SDK): `Prompt` y `LanguageModelSession` son estrictamente de texto, no existe `ModelContentItem.image` ni ningún tipo que acepte imágenes. El framework on-device de Apple **no soporta entrada visual** a día de hoy. El fallback de confianza 0 en `HealthAgent.analyzeFoodPhoto` es el comportamiento correcto y definitivo (no un placeholder pendiente de completar). Si se quiere una estimación real a partir de la foto, la vía es Vision (`ClassifyImageRequest`, iOS 18+) para clasificación general de escena, no un LLM — evaluar como mejora futura fuera del alcance de FoundationModels. |
| 3 | interpretLabResults con texto plano | ✅ RESUELTO v2 — ahora usa LabInterpretationSchema (@Generable) | Confirmado en código |
| 4 | @available en propiedades stored de LanguageModelSession | ✅ RESUELTO | Una propiedad *stored* no puede llevar `@available` (restricción del lenguaje, independiente de `@Observable`). Se guarda como `Any?` (`_session`) sin tracking y se expone como *computed property* tipada con `@available` que delega en el respaldo (HealthAgent.swift). |
| 5 | Errores de la sesión (cómo detectar "modelo no disponible") | Implementado | startSession captura con do/catch y setea aiAvailable=false. Pendiente de probar en dispositivo físico sin Apple Intelligence (no disponible en este entorno de build). |

## 9. Log de verificación de fuentes

- ✅ LanguageModelSession.init(model:tools:instructions:) — confirmado en Apple Developer Documentation y compila
- ✅ SystemLanguageModel.default — confirmado en Apple Developer Documentation y compila
- ✅ respond(to:generating:includeSchemaInPrompt:options:) — confirmado en Apple Developer Documentation
- ✅ Patrón let response = try await session... + .content — confirmado en WWDC25 Session 286 (Meet the Foundation Models framework)
- ✅ @Generable / @Guide — confirmado en WWDC25 Sessions 286 y 301
- ✅ FoundationModels no disponible en simulador — requiere dispositivo físico con Apple Intelligence
- ✅ Sin entitlement requerido para FoundationModels — confirmado con Xcode real al firmar ("com.apple.developer.foundation-models not found... not a valid entitlement, should be removed")
- ✅ SystemLanguageModel.default — confirmado compilando con Xcode 26 / iOS 26.5 SDK
- ✅ FoundationModels no expone ninguna API de imagen — confirmado inspeccionando el `.swiftinterface` del framework en el SDK de iOS 26.5

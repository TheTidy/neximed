# 🩺 Neximed — Roadmap de Desarrollo y Publicación en App Store (detallado)

> **Visión**: La plataforma personal de salud **Voice-First** y 100% on-device más completa, privada y rigurosa. Unifica datos de Apple Watch, analíticas de laboratorio, botiquín de medicación, registro de síntomas y consultas médicas mediante **dictado por voz natural refinado por IA**, generando un **Dossier Clínico en PDF estructurado en 1 página** para tu médico.

> **Marca definitiva**: Neximed
> **Documentos vinculados**: AI-ARCHITECTURE.md (detalle técnico de la IA) · PUBLISHING-CHECKLIST.md (App Store) · prompts.md + promptsgemini.md (assets)

---

## 📋 Estado actual del proyecto (inventario real)

| Módulo | Estado | Archivo |
|--------|--------|---------|
| Sistema de diseño (tokens exactos de marca) | ✅ Hecho | Neximed/Sources/Neximed/DesignSystem/DesignSystem.swift |
| Conector HealthKit (actividad, cardio, sueño, nutrición) | ✅ Hecho | HealthKitManager.swift |
| Modelos SwiftData (perfil, botiquín, síntomas, consultas, analíticas) | ✅ Hecho | HealthModels.swift |
| Dashboard + gráficas Swift Charts | ✅ Hecho | DashboardView.swift, SecondaryViews.swift |
| Dictado por voz on-device (es-ES) | ✅ Hecho | VoiceDictationManager.swift |
| Agente IA con fallback determinista | ✅ Hecho | HealthAgent.swift |
| Dossier PDF 1 página | ✅ Hecho | MedicalReportExporter.swift |
| Escáner OCR analíticas (25 marcadores) | ✅ Hecho | LabScanner.swift |
| Análisis de comida (foto + código de barras) | ⚠️ Código de barras real; foto con IA no soportada — ver nota | FoodAnalyzer.swift |
| App Intents Siri | ✅ Hecho | HealthIntents.swift |
| Proyecto Xcode (XcodeGen) | ✅ Hecho y compila (ver HITO A) | project.yml |
| Assets (AppIcon, AccentColor) | ✅ Hecho — PNG 1024×1024 presente y configurado | Assets.xcassets |
| ShareSheet (compartir PDF) | ✅ Hecho | ShareSheet.swift |

**Bloqueantes resueltos en sesión anterior**:
- ✅ Proyecto Xcode reproducible (XcodeGen)
- ✅ Fallback de Apple Intelligence (modo básico)
- ✅ Renombrado MacSalud → Neximed completo
- ✅ Errores de compilación detectados y corregidos (FoodAnalysis, ShareSheet)

**Bloqueantes resueltos en esta sesión (2026-08-24) — validado con Xcode/xcodebuild reales**:
- ✅ HITO A completado: `xcodebuild` compila y archiva sin errores (simulador, dispositivo arm64 y archive Release). Ver detalle en QUALITY-AUDIT.md.
- ✅ Nota de comida por foto con IA: confirmado con el SDK de iOS 26 que `FoundationModels` no expone ninguna API de imagen (`Prompt`/`LanguageModelSession` son solo texto). El fallback de confianza 0 es el comportamiento correcto y definitivo, no un TODO pendiente de validar.
- ✅ `UIRequiresFullScreen` corregido a `true` (evita warning/posible rechazo de validación en App Store Connect, dado que la app es solo portrait/iPhone).

---

## 🗺️ Roadmap por hitos con desglose de tareas

### 🥇 HITO A — Build Verde en tu Mac *(día 1-3)*

**Objetivo**: compilar y ejecutar en dispositivo real sin errores.

| # | Tarea | Tiempo | Depende de |
|---|-------|--------|-----------|
| A1 | Instalar XcodeGen: brew install xcodegen | 10 min | Mac con brew | ✅ Hecho |
| A2 | Generar proyecto: xcodegen generate | 5 min | A1 | ✅ Hecho |
| A3 | Abrir Neximed.xcodeproj, seleccionar Team de firma | 10 min | A2 + cuenta Apple | ⬜ Pendiente (requiere cuenta de desarrollador, ver B1) |
| A4 | Compilar ⌘B y resolver errores del compilador real | 2-4 h | A3 | ✅ Hecho (2026-08-24): ~25 errores de compilación reales corregidos (comas y sintaxis en FoodDatabase, APIs de HealthKit no-opcionales, Sendable/concurrencia Swift 6 en HealthAgent/VoiceDictationManager/HealthIntents/ScreenTimeManager, ModelConfiguration inventado en NeximedApp, `.msX` shorthand en ShapeStyle, `MedicationType` sin CaseIterable, punto y coma sueltos en 3 vistas, etc. Detalle en QUALITY-AUDIT.md) |
| A5 | Validar puntos abiertos de IA (sección 8 de AI-ARCHITECTURE.md) | 2-3 h | A4 | ✅ Hecho — confirmado con el SDK de iOS 26: FoundationModels no tiene API de imagen; ver AI-ARCHITECTURE.md §8 |
| A6 | Probar en iPhone físico: HealthKit, dictado, OCR, PDF | 3-4 h | A5 | ⬜ Pendiente — requiere dispositivo físico y firma con cuenta Apple (no disponible en este entorno) |
| A7 | Probar en iPhone sin Apple Intelligence (modo básico) | 1-2 h | A6 | ⬜ Pendiente — igual que A6 |

**Criterio de aceptación**: la app se instala y completa el flujo completo (HealthKit → dictado → dossier → compartir) sin crashes en 2 dispositivos.

**Estado real (2026-08-24)**: `xcodebuild` compila y **archiva** (Release, sin firma) sin errores para simulador y dispositivo arm64. Esto es la primera vez que el proyecto compila de verdad — las sesiones anteriores documentaban ✅ Hecho sin haber ejecutado nunca un build real. Falta únicamente la parte que requiere hardware/cuenta Apple: firmar con un Team, instalar en un iPhone físico y probar el flujo end-to-end (A3, A6, A7).

---

### 📱 HITO B — Material App Store y Cuenta *(día 4-7)*

**Objetivo**: assets y configuración de App Store Connect listos para TestFlight.

| # | Tarea | Tiempo | Depende de |
|---|-------|--------|-----------|
| B1 | Cuenta de desarrollador Apple (99 $/año) + registro bundle ID com.neximed.app | 1-2 h | — |
| B2 | Política de privacidad pública (obligatoria con HealthKit) — hosting GitHub Pages/Notion | 2-3 h | — |
| B3 | Generar icono 1024×1024 (PROMPT 1 de promptsgemini.md) → AppIcon.png | 1-2 h | Gemini/Imagen |
| B4 | Generar banner 16:9 (PROMPT 3) y fondos de screenshots (PROMPT 7) | 1-2 h | B3 |
| B5 | Capturar screenshots 6.7" reales (4 pantallas) | 2-3 h | A6 |
| B6 | Completar ficha App Store Connect (categoría Salud y bienestar, cuestionario de datos de salud) | 2 h | B1-B5 |
| B7 | Subir build a TestFlight (Archive → Distribute) | 1 h | A6 + B1 |

**Criterio de aceptación**: build instalable vía TestFlight en 2 dispositivos + ficha completa.

---

### 🧪 HITO C — TestFlight y Revisión *(día 8-12)*

**Objetivo**: pasar la revisión de Apple y publicar v1.0.

| # | Tarea | Tiempo | Depende de |
|---|-------|--------|-----------|
| C1 | Test con testers internos (5-10 personas) | 2-3 días | B7 |
| C2 | Corregir bugs reportados y re-subir build | 1-2 días | C1 |
| C3 | Notas para la revisión: app de organización personal, sin diagnóstico, todo on-device | 30 min | C2 |
| C4 | Enviar a revisión → esperar 24-72 h | — | C3 |
| C5 | Responder posibles preguntas del revisor | 1-2 h | C4 |
| C6 | v1.0 publicada 🚀 | — | C5 |

**Criterio de aceptación**: app visible en la App Store con descarga funcionando.

---

### 🌟 HITO D — v1.1: Experiencia Ampliada *(semanas 3-5)*

**Objetivo**: profundizar en seguimiento y ecosistema. (Fase 2 del plan original)

| # | Tarea | Prioridad |
|---|-------|-----------|
| D1 | Comparativa longitudinal de analíticas: gráfica multianual de marcadores con Swift Charts (Chart + LineMark) | Alta |
| D2 | Ficha de Emergencias ICE: grupo sanguíneo, alergias, contacto de emergencia, acceso rápido desde Dashboard | Alta |
| D3 | App Intents Siri ya implementados — añadir intent de dictado por voz "Oye Siri, anota un síntoma" | Media |
| D4 | Deep-link + share sheet mejorado para el dossier | Baja |

---

### 🏥 HITO E — v1.2: Archivo Clínico y Ecosistema *(semanas 5-8)*

**Objetivo**: cerrar el ciclo completo. (Fase 3 del plan original)

| # | Tarea | Prioridad | Nota técnica |
|---|-------|-----------|--------------|
| E1 | Diario Post-Consulta (pautas del doctor + recordatorios de revisiones) | Alta | SwiftData + UNUserNotificationCenter |
| E2 | Exportación FHIR JSON | Media | Requiere re-activar health-records entitlement (aprobación especial de Apple) |
| E3 | Complicación Apple Watch para dictar síntomas | Media | Nuevo target watchOS |
| E4 | Widget de pantalla de inicio (recordatorio de cita) | Media | WidgetKit + SwiftData compartido (App Group) |

---

## 🔍 Detalle del sistema de IA (resumen ejecutivo)

El detalle completo con prompts exactos, flujos y fallbacks está en **AI-ARCHITECTURE.md**. Resumen:

- **Motor**: FoundationModels (Apple Intelligence), 100% on-device, iOS 26+.
- **4 funciones IA**: refinamiento de dictado, chat asistente, preparación de consulta, interpretación de analíticas.
- **Degradación elegante**: en cualquier iPhone (iOS 17+) las 4 funciones responden con fallbacks deterministas usando datos reales de HealthKit (flag aiAvailable).
- **APIs verificadas con fuentes oficiales**: LanguageModelSession, SystemLanguageModel, Instructions, Prompt, respond(to:generating:), macros @Generable y @Guide.

---

## ⚠️ Riesgos y bloqueantes de publicación

| # | Riesgo | Mitigación |
|---|--------|-----------|
| 1 | Apple Intelligence no disponible en España/idioma español (limitado) | Fallback determinista = experiencia principal; app completa sin IA |
| 2 | health-records (FHIR) requiere aprobación especial | Diferido a v1.2 (E2); fuera de entitlements del MVP |
| 3 | Apps de salud se revisan con lupa | Notas de revisión claras: organización personal, sin diagnóstico, on-device |
| 4 | Simulador no soporta FoundationModels ni HealthKit completo | Pruebas siempre en dispositivo físico |
| 5 | Puntos abiertos de API IA (sección 8 de AI-ARCHITECTURE) | Validar en el build real del Mac y ajustar según compilador |

---

## 🧰 Decisiones técnicas clave (invariantes)

1. **Deployment target iOS 17.0** — máxima base instalada; IA se degrada con elegancia.
2. **XcodeGen** — proyecto reproducible desde project.yml (sin conflictos de merge).
3. **SwiftData local** con cloudKitDatabase: .none — privacidad zero-knowledge, sin servidores.
4. **requiresOnDeviceRecognition = true** en dictado — la voz nunca sale del dispositivo.
5. **HealthKit solo lectura de constantes + escritura de nutrición** — sin Health Records en v1.0.
6. **Modo Básico siempre funcional** — cada función de IA tiene su fallback determinista.
### 🔐 Seguridad implementada (bloqueo biométrico)

| Medida | Estado | Archivo |
|--------|--------|---------|
| Bloqueo Face ID / Touch ID / código | ✅ Hecho | Security/SecurityManager.swift |
| Pantalla de bloqueo AppLockView | ✅ Hecho | Security/AppLockView.swift |
| Bloqueo automático al pasar a background | ✅ Hecho | UI/ContentView.swift (scenePhase) |
| Redacción de datos sensibles en capturas (privacySensitive) | ✅ Hecho | DashboardView, AgentChatView, SecondaryViews |
| Cifrado en reposo (completeUntilFirstUserAuthentication) | ✅ Hecho | NeximedApp.swift |

Detalle completo en [SECURITY.md](SECURITY.md).

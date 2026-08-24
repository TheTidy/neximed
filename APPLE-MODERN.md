# 🍎 Neximed — Alineación con las Prácticas Modernas de Apple

> Documento que explica cómo Neximed usa **lo último en Xcode** y sigue los
> patrones que Apple recomienda en sus sesiones (WWDC23-25) y apps de ejemplo.

---

## ✅ Migración realizada: @Observable (patrón moderno de estado)

Apple dejó de recomendar ``ObservableObject`` + ``@Published`` + ``@StateObject`` desde
iOS 17 (WWDC23 — 'Discover Observation in SwiftUI'). Todas las apps de ejemplo
nuevas de Apple usan el macro **@Observable**.

### Cambios aplicados

| Antes (obsoleto) | Ahora (recomendado por Apple) |
|------------------|-------------------------------|
| ``ObservableObject`` | ``@Observable`` (macro) |
| ``@Published var x`` | ``var x`` (el macro observa todo) |
| ``@StateObject private var s = M.shared`` | ``@State private var s = M.shared`` |
| ``@ObservedObject`` | ``@State`` o ``@Bindable`` según contexto |

### Archivos migrados (6 managers + 7 vistas)

- HealthKitManager, HealthAgent, VoiceDictationManager, LabScanner, FoodAnalyzer, SecurityManager
- ContentView, DashboardView, AgentChatView, SecondaryViews, VoiceDictationSheet, AppLockView

---

## ✅ Swift 6 (Xcode 26)

- ``SWIFT_VERSION: 6.0`` en project.yml
- ``SWIFT_STRICT_CONCURRENCY: minimal`` — modo de migración recomendado por Apple
  (el paso final a ``complete`` se hace cuando el compilador del Mac lo valide)
- ``SWIFT_APPROACHABLE_CONCURRENCY: YES`` — funciones async y ``nonisolated``
  implícitas (Swift 6.1+)
- ``nonisolated(unsafe)`` en las propiedades accedidas desde el hilo de audio
  (patrón de Apple en SpeakToMe para SFSpeechAudioBufferRecognitionRequest)

---

## ✅ Otros patrones modernos ya aplicados

| Práctica de Apple | Estado |
|-------------------|--------|
| SwiftData (en vez de Core Data) | ✅ desde el inicio |
| Swift Charts (en vez de gráficas custom) | ✅ Dashboard, Nutrición, Tendencias |
| ``NavigationStack`` (en vez de ``NavigationView`` deprecado) | ✅ eliminado NavigationView |
| App Intents + AppShortcutsProvider (Siri) | ✅ HealthIntents.swift |
| FoundationModels (Apple Intelligence on-device) | ✅ con fallback iOS 17+ |
| ``#Preview`` macros | ✅ AgentChatView, AppLockView |
| ``.privacySensitive()`` (redacción de datos sensibles) | ✅ Dashboard, Labs, Chat |
| LocalAuthentication (Face ID / Touch ID) | ✅ SecurityManager |
| File Protection (``completeUntilFirstUserAuthentication``) | ✅ ModelContainer |
| Inicializador ``Color(hex:)`` + tokens de diseño | ✅ DesignSystem |

---

## 🔮 Siguientes pasos para alinearse 100% (cuando el build del Mac funcione)

1. **Subir ``SWIFT_STRICT_CONCURRENCY`` a ``complete``** y resolver los errores de
   Sendable que el compilador reporte (los singletons ya son @MainActor).
2. **Localización con String Catalog** (Localizable.xcstrings) — las apps de
   ejemplo de Apple están localizadas; la app está en español, se puede añadir
   inglés para ampliar el alcance.
3. **Accessibility**: Dynamic Type, VoiceOver, Reduce Motion — verificar con el
   Auditor de accesibilidad de Xcode.
4. **Widgets + App Intents avanzados** (Hito D/E del roadmap).
5. **Xcode Cloud / TestFlight automation** para CI de builds.

---

## 📌 Nota importante sobre Swift 6

El código fue escrito originalmente antes de Swift 6. Aunque la migración a
``@Observable`` y las correcciones de concurrencia están hechas, **el compilador
real del Mac puede reportar errores de Sendable/aislamiento** que solo aparecen
al compilar. Si ocurre, pégame el error exacto y lo resolvemos — es parte del
proceso normal de migración que Apple documenta.
# 🔧 Neximed — Auditoría de Calidad de Ingeniería

> Documento de registro: problemas detectados y corregidos para garantizar una app
> **suave, sin bloqueos, sin fugas de memoria y sin código huérfano**.

---

## 🚨 CRÍTICO: Continuations colgadas (hang silencioso permanente)

**Problema**: 4 funciones usaban ``try? handler.perform([request])`` dentro de
``withCheckedThrowingContinuation``. Si ``perform`` lanzaba un error, el closure
del request **nunca se ejecutaba** y la continuation **nunca se resolvía** →
el hilo quedaba bloqueado para siempre sin error visible.

**Corregido en**:
| Archivo | Función | Fix |
|---------|---------|-----|
| FoodAnalyzer.swift | preprocessImage | do/catch + resume con imagen comprimida |
| FoodAnalyzer.swift | scanBarcode | do/catch + resume con nil |
| FoodAnalyzer.swift | scanNutritionLabel | do/catch + resume con nil |
| LabScanner.swift | performOCR | do/catch + resume con cadena vacía |

**Verificación**: 0 restantes de ``try? handler.perform`` ✅

---

## ⚡ RENDIMIENTO: Hilo de audio en tiempo real

**Problema**: en ``VoiceDictationManager``, el callback de ``installTap`` (hilo de
audio en tiempo real, cada ~21 ms) hacía:
- ``Array(UnsafeBufferPointer(...))`` → asignación de memoria por buffer
- Bucle manual de RMS
- ``Task { @MainActor }`` por cada buffer → saturación del main actor

**Corregido**:
- RMS con ``vDSP_rmsqv`` (Accelerate, vectorizado, sin allocation)
- Throttling: solo salta al main actor si el nivel cambió > 0.02
- ``lastAudioLevel`` como almacén local sin @Published

---

## 🎤 Grabación: resultado final perdido

**Problema**: ``stopRecording()`` usaba ``recognitionTask?.cancel()`` que descarta
la transcripción final (las últimas palabras dictadas se perdían).

**Corregido**:
- ``recognitionTask?.finish()`` → entrega el resultado final
- ``guard isRecording`` → evita doble detención (el callback también la invoca)
- ``forceCleanup()`` separada → limpieza incondicional desde ``startRecording``

---

## 🛡️ Validación de disponibilidad

**Problema**: ``speechRecognizer`` podía ser ``nil`` (simulador / idioma no
descargado) y ``startRecording`` seguía grabando sin transcripción.

**Corregido**: ``guard let recognizer, recognizer.isAvailable`` → lanza
``VoiceError.recognizerUnavailable`` antes de tocar el audio.

---

## 🧹 Código muerto eliminado (escrituras sin lecturas)

| Símbolo | Archivo | Estado |
|---------|---------|--------|
| lastAnalysis | FoodAnalyzer | Eliminado (nadie lo leía) |
| streamingText | HealthAgent | Eliminado (nadie lo leía) |
| lastResponse | HealthAgent | Eliminado (nadie lo leía) |

---

## 🧩 Funciones huérfanas integradas (no eliminadas)

| Función | Uso encontrado |
|---------|----------------|
| LabScanner.scanPDF | Conectada a LabsView: botón Importar PDF + fileImporter |
| FoodAnalyzer.scanBarcode | Conectada a NutritionView: BarcodeScannerView + BarcodeResultCard |
| HealthRing | Integrado en DashboardView: anillo de objetivo de descanso |
| HealthBadge | Integrado en el anillo (objetivo cumplido / en progreso) |

---

## 🔍 Errores silenciados revisados

- ✅ ContentView ya no usa try? en HealthKit: captura el error y lo guarda en healthKit.lastError
- ✅ Los try? restantes son aceptables (fallos opcionales de UI, no dejan estado inconsistente)
- ⚠️ fatalError en NeximedApp: intencional (el ModelContainer es crítico de arranque)

---

## ✅ Comprobaciones finales

- [x] 0 continuations colgadas
- [x] 0 try? handler.perform sin manejo
- [x] 0 funciones con escrituras sin lectura
- [x] Todas las funciones implementadas tienen uso real en la UI
- [x] Hilo de audio optimizado (vDSP + throttling)
- [x] [weak self] en closures de audio y recognition
- [x] Sin bucles infinitos (while/repeat = 0)
- [x] Sin try! (crash) en todo el proyecto
- [x] Sin DispatchQueue ni Timers (concurrencia moderna Swift)
---

## 🚀 FLUIDEZ DE NAVEGACIÓN (sesión 2)

### Cuello de botella #1 — TabView .page precargaba TODAS las pestañas

**Problema**: ContentView usaba ``TabView`` + ``.tabViewStyle(.page)``. Esto crea un
UIPageViewController que **precarga las páginas adyacentes** → montaba las 5 vistas
a la vez y disparaba sus queries de HealthKit en el arranque (Dashboard + Nutrition +
AgentChat juntos). Moverse entre pestañas era lento y consumía memoria.

**Corregido**: switch que monta SOLO la pestaña activa + ``.id(selectedTab)`` +
``.transition(.opacity)`` para suavidad. Las otras vistas no existen hasta que se
seleccionan.

### Cuello de botella #2 — OCR de Vision en el hilo principal

**Problema**: LabScanner y FoodAnalyzer son @MainActor, así que ``handler.perform()``
(síncrono y pesado) congelaba la UI durante cada escaneo.

**Corregido**: ``DispatchQueue.global(qos: .userInitiated).async`` alrededor del perform
en los 4 puntos (LabScanner.performOCR + FoodAnalyzer preprocessImage/scanBarcode/
scanNutritionLabel). La UI sigue respondiendo mientras Vision procesa.

### Cuello de botella #3 — NavigationView deprecado en DashboardView

**Problema**: envoltura NavigationView sin navegación real (overhead + API deprecada).

**Corregido**: eliminado; el ScrollView es ahora el root. (Se detectó y reparó una
llave extra que quedó tras la extracción — verificado con analizador de balance).

### Cuello de botella #4 — generatePDF síncrono en el hilo principal

**Problema**: exportDoctorPDF renderizaba el PDF A4 en el main thread → micro-bloqueo
al pulsar 'Generar Dossier'.

**Corregido**: ``Task.detached(priority: .userInitiated)`` para el render +
``await MainActor.run`` para actualizar el estado. UIGraphicsPDFRenderer es thread-safe.

### Cuello de botella #5 — Dashboard esperaba a la IA antes de mostrar datos

**Problema**: .task cargaba HealthKit Y esperaba generateDoctorVisitPrep (IA) — el
dashboard quedaba en blanco durante segundos en dispositivos con IA.

**Corregido**: datos de HealthKit primero (queries en paralelo), la preparación de
consulta se lanza después sin bloquear la vista.

### Extras de higiene

- isLoading en DashboardView: eliminado (se escribía, nunca se leía)
- errorMessage de VoiceDictationManager: ahora se muestra en el sheet (antes se
  escribía sin mostrarse — habría sido código muerto)
- startRecordingFlow: captura y muestra el error de reconocimiento no disponible

### ✅ Verificación final

- [x] Balance de llaves correcto en los 13 archivos Swift (analizador de profundidad)
- [x] 0 operaciones pesadas síncronas en el main thread (OCR y PDF en background)
- [x] Navegación por switch: solo la pestaña activa está en memoria
- [x] 0 código muerto nuevo introducido
- [x] Transición suave entre pestañas (.opacity)

---

## 🚀 Splash Screen con Barra de Carga REAL

La app arranca con un splash que muestra el progreso REAL de inicialización,
no una animación falsa. El orquestador AppBootstrapper ejecuta los pasos y
actualiza la barra en cada uno:

| Paso | Progreso | Qué hace realmente |
|------|----------|---------------------|
| Comprobando dispositivo | 5% | SecurityManager.checkBiometricsAvailability() |
| Base de datos segura | 15% | Verificación del contenedor SwiftData |
| Conectando Apple Health | 30% | HealthKit requestAuthorization() |
| Cargando tus constantes | 50% | precarga 14 días de datos (cache) |
| Preparando tu asistente | 80% | Sesión del agente IA on-device |
| Listo | 100% | Transición a la app |

### Beneficio: la app VUELA después del splash

Los datos de HealthKit se precargan en cache durante el splash. Dashboard,
Nutrición y Tendencias **leen el cache al instante** en lugar de re-consultar
HealthKit → las vistas se muestran con datos al entrar, sin esperas.

### Archivos

- Bootstrap/AppBootstrapper.swift — orquestador con pasos reales
- Bootstrap/SplashScreenView.swift — splash con barra de progreso
- HealthKitManager: cache (cachedActivity/Cardio/Sleep/Nutrition + preloadData)
- DashboardView/NutritionView/TrendsView: leen el cache si didPreload

---

## 🛠️ Sesión 3 (2026-08-24) — Primer build real con Xcode/xcodebuild

Todas las sesiones anteriores documentaban el proyecto como "✅ Hecho" sin haber
ejecutado nunca `xcodegen generate` + `xcodebuild` en un Xcode real. Al hacerlo
por primera vez, el proyecto **no compilaba**: ~25 errores de compilador reales,
repartidos en 13 archivos. Todos corregidos y verificados con:
- `xcodebuild build` para `iphonesimulator` (Debug, arm64 + x86_64)
- `xcodebuild build` para `iphoneos` (dispositivo real, arm64, sin firma)
- `xcodebuild archive` (Release, sin firma) — el flujo real de publicación

### Errores corregidos

| Archivo | Problema | Fix |
|---------|----------|-----|
| Nutrition/FoodDatabase.swift | 2 comas ausentes entre literales `FoodItem(...)` (error de sintaxis, rompía todo el fichero) | Comas añadidas |
| HealthKit/HealthKitManager.swift | `HKCategoryType(_:)` y `HKElectrocardiogramType.electrocardiogramType()` tratados como opcionales (`if let`) cuando son no-opcionales en el SDK actual; `CardioSnapshot`/`SleepSnapshot`/`NutritionSnapshot` inicializados con argumentos (`ecgClassification`, `sleepScore`, `consistencyScore`, `sugar`, `sodium`) que no existen en esos structs; `activity.map(\.steps)` sin convertir a `Double` | `if let` eliminados; argumentos inexistentes retirados de las llamadas; `\.steps` envuelto en `{ Double($0.steps) }` |
| NeximedApp.swift | `ModelConfiguration(..., protectionType:)` — ese parámetro no existe en SwiftData | Parámetro eliminado (iOS ya aplica `NSFileProtectionCompleteUntilFirstUserAuthentication` por defecto al contenedor de la app) |
| Agent/HealthAgent.swift | Propiedad *stored* `session` marcada `@available` — no permitido por el lenguaje, agravado por el macro `@Observable` | Respaldo `_session: Any?` con `@ObservationIgnored` + computed property `session` tipada con `@available` |
| Agent/AgentPrompts.swift | `AgentPrompts.Language.current` (nonisolated) leía `LanguageManager.shared` (`@MainActor`) | `current` marcado `@MainActor` |
| Voice/VoiceDictationManager.swift | `Self.makeRecognizer()` en inicializador de propiedad stored (tipo covariante no permitido ahí); `speechRecognizer`/`makeRecognizer()` marcados `nonisolated` pero leían `LanguageManager.shared` (`@MainActor`); `deinit` (siempre nonisolated) leía `languageObserver` sin marcar | `Self` → nombre de tipo explícito; `nonisolated` retirado de `speechRecognizer`/`makeRecognizer()` (la clase ya es `@MainActor`); `languageObserver` marcado `nonisolated(unsafe)` para el acceso desde `deinit` |
| Nutrition/FoodAnalyzer.swift | `FoodDatabaseService` sin stored properties mutables pero no `Sendable` (error de concurrencia Swift 6) | Conformidad `Sendable` añadida |
| Intents/HealthIntents.swift | `static var title/description/openAppWhenRun` = estado mutable global no-Sendable (Swift 6); `@Parameter(defaultValue:)` — la etiqueta real de la API es `default:` | `static var` → `static let`; `defaultValue:` → `default:` |
| DesignSystem/DesignSystem.swift | `.msAccent`, `.msTextPrimary`, etc. usados como azúcar de punto en `foregroundStyle(_:)`/`fill(_:)` (genéricos sobre `ShapeStyle`) — solo estaban definidos como estáticos de `Color`, no de `ShapeStyle` | Extensión puente `extension ShapeStyle where Self == Color { static var msX: Color { .msX } }` para cada token |
| Export/DataExporter.swift | `Character(13)`/`Character(10)` — no existe ese inicializador de `Character` | `"\r\n"` literal |
| Labs/LabScanner.swift | `PDFPage.thumbnail(of:for:)` tratado como opcional (`if let`) cuando devuelve `UIImage` no-opcional | `if let` eliminado |
| ScreenTime/ScreenTimeManager.swift | `center.requestAuthorization(for:)` — "sending self.center risks causing data races" (FamilyControls no auditado para Sendable, Swift 6 estricto) | `@preconcurrency import FamilyControls` |
| UI/MedicalReportExporter.swift | `"\(marker.value, specifier: "%.1f")"` — la interpolación `specifier:` es exclusiva de `Text` de SwiftUI, no de `String` | `String(format: "%.1f", marker.value)` |
| UI/MedicationDetailView.swift, UI/MedicationListView.swift | Puntos y coma sueltos tras `Label(...)`/`Text(...)` que cortaban la cadena de modificadores SwiftUI en 3 sitios | Puntos y coma eliminados |
| UI/MedicationListView.swift | `MedicationEntry.MedicationType` sin `CaseIterable` (usado con `.allCases` en un Picker) | Conformidad `CaseIterable` añadida |
| UI/SecondaryViews.swift | `modelContext.insert(meal)` sobre `MealEntry`, que es un `struct` plano (no `@Model` de SwiftData) | Llamada eliminada; las comidas se persisten solo vía HealthKit, como en el resto de la app |
| project.yml | `UIRequiresFullScreen: false` + orientación solo portrait → warning de Xcode ("All interface orientations must be supported unless the app requires full screen"), riesgo de rechazo en validación de App Store Connect | `UIRequiresFullScreen: true` |
| project.yml / Neximed.entitlements | `com.apple.developer.foundation-models` — entitlement inventado (no existe). Confirmado al intentar firmar: "Entitlement com.apple.developer.foundation-models not found and could not be included in profile. This likely is not a valid entitlement and should be removed from your entitlements file." | Eliminado de `project.yml`. FoundationModels no requiere entitlement de app; el acceso se controla en runtime por capacidad del dispositivo (`SystemLanguageModel.default.availability`). `com.apple.developer.healthkit` y `com.apple.developer.siri` sí son entitlements reales y se mantienen. |

### ✅ Verificación final

- [x] `xcodebuild build` (iphonesimulator, Debug) — BUILD SUCCEEDED
- [x] `xcodebuild build` (iphoneos, dispositivo real arm64, sin firma) — BUILD SUCCEEDED, sin warnings
- [x] `xcodebuild archive` (Release, sin firma) — ARCHIVE SUCCEEDED
- [x] Punto abierto de AI-ARCHITECTURE.md §8 sobre `ModelContentItem.image` cerrado: confirmado que no existe en el SDK (ver AI-ARCHITECTURE.md)

### Pendiente (requiere hardware/cuenta que no están disponibles en este entorno)

- Firmar con un Team de Apple Developer real y probar en iPhone físico (HITO A3/A6/A7 de plan.md)
- Validar el flujo de IA en un dispositivo con Apple Intelligence real (el simulador no lo soporta)

---

## 🛠️ Sesión 4 (2026-08-24) — Reporte del usuario tras probar la app

El usuario, ya con firma real de Apple Developer, reportó dos problemas al probar la app:

### 1. "Entitlement com.apple.developer.foundation-models not found"

Xcode rechazó ese entitlement al firmar. Confirmaba lo que ya se sospechaba: es
un entitlement inventado, no uno real de Apple. FoundationModels/Apple
Intelligence no requiere entitlement de app — el acceso se controla en runtime
por capacidad del dispositivo. Eliminado de `project.yml` y de
`Neximed.entitlements` (se regenera solo con `com.apple.developer.healthkit` y
`com.apple.developer.siri`, que sí son reales).

### 2. "Al iniciar por primera vez parece que tarda mucho... no sé si está bloqueado"

Causa real encontrada: **`HealthAgent.startSession()` duplicaba todas las
queries de HealthKit que `AppBootstrapper` ya acababa de hacer.** El paso 4 del
splash (`preloadData(days: 14)`) consulta actividad/cardio/sueño/nutrición y
las guarda en cache (`cachedActivity`, etc.), pero el paso 5
(`HealthAgent.startSession` → `buildHealthContext(days: 14)`) volvía a pedirle
a HealthKit exactamente los mismos 14 días de datos desde cero, sin usar ese
cache — duplicando el tiempo de esa parte del arranque. Esto era justo lo
contrario de lo que documentaba la sesión 2 ("Dashboard, Nutrición y Tendencias
leen el cache al instante"): `buildHealthContext` se quedó fuera de ese cambio.

**Fix**: `HealthKitManager.buildHealthContext(days:)` ahora usa el cache
(`cachedActivity`/`cachedCardio`/`cachedSleep`/`cachedNutrition`) cuando
`didPreload == true`, tomando los últimos `days` con `.suffix(days)` en vez de
volver a consultar HealthKit. Esto también acelera las llamadas de IA en uso
normal (preparación de consulta, interpretación de analíticas), que también
pasan por `buildHealthContext`.

### 3. "Además falta el icono y el splash screen al menos"

Dos problemas de assets reales, no de código:

- **AppIcon.png tenía canal alfa y no llegaba a los bordes.** El PNG de
  1024×1024 tenía el cross-logo dibujado sobre un cuadrado más pequeño con
  esquinas ya redondeadas, rodeado de blanco (con alfa parcial en las
  esquinas). Apple exige que el icono de marketing de 1024×1024 sea opaco y a
  sangre completa — iOS aplica su propio recorte de esquinas; si el arte no
  llega al borde, se ve un marco blanco alrededor del icono, y además
  App Store Connect puede rechazar un icono con canal alfa en la validación.
  Se recortó al bounding box del arte real, se rellenaron las esquinas
  residuales con el tono de fondo de la propia marca (`#0D1117`, igual que
  `msBackground`) y se re-escaló a 1024×1024 sin canal alfa.
- **`UILaunchScreen: {}` en project.yml era una pantalla de arranque nativa en
  blanco.** Esa es la pantalla que iOS pinta al instante, antes de que
  cualquier código Swift se ejecute — no tiene nada que ver con el
  `SplashScreenView.swift` a medida (que sí estaba bien montado en
  `NeximedApp.swift`, pero solo aparece un instante después). Con `{}` esa
  primera pantalla nativa es blanca/vacía, lo que se percibe como "no hay
  splash". Se configuró con `UIColorName: LaunchBackground` (nuevo Color Set
  con el tono `#0D1117` de la marca) y `UIImageName: splash-centerpiece`
  (mismo asset que ya usa el splash a medida), para que la primerísima
  pantalla ya muestre la marca en vez de quedar en blanco.

### ✅ Verificación final (sesión 4)

- [x] `xcodebuild build` (iphonesimulator) — BUILD SUCCEEDED
- [x] `xcodebuild build` (iphoneos, dispositivo real arm64, sin firma) — BUILD SUCCEEDED
- [x] `xcodebuild archive` (Release, sin firma) — ARCHIVE SUCCEEDED
- [x] `Info.plist` generado confirma `UILaunchScreen` con `UIColorName`/`UIImageName` correctos
- [x] `AppIcon.png` verificado: 1024×1024, sin canal alfa, arte a sangre completa

---

## 🛠️ Sesión 5 (2026-08-24) — Crash real reproducido y corregido: "Neximed se ha cerrado inesperadamente"

El usuario reportó que la app se cerraba sola justo después de arrancar. Se
reprodujo lanzándola en un simulador (`xcrun simctl`) y se leyó el `.ips`
generado por macOS en `~/Library/Logs/DiagnosticReports/`.

### Causa raíz

`EXC_CRASH` / `SIGABRT` por una `NSException` sin capturar, lanzada por
HealthKit al validar la query, no por un bug de Swift:

```
HealthKit -[HKQuantityType ... supportsStatisticOptions:]
HealthKit +[HKStatistics _validateOptions:forDataType:]
HealthKit -[HKStatisticsCollectionQuery queue_validate]
Neximed.debug.dylib  HealthKitManager.fetchDailyQuantities(_:from:to:unit:)  (HealthKitManager.swift:355)
Neximed.debug.dylib  implicit closure #3 in HealthKitManager.fetchCardioSummary(for:)  (HealthKitManager.swift:201)
```

`fetchDailyQuantities` solo trataba `.heartRate` y `.heartRateVariabilitySDNN`
como tipos discretos (`.discreteAverage`); todo lo demás recibía
`.cumulativeSum`. Pero `fetchCardioSummary` también consulta
`.restingHeartRate` y `.walkingHeartRateAverage`, que son tipos **discretos**,
no acumulativos. HealthKit lanza una excepción (no un error Swift, no
capturable con `do/catch` normal) en cuanto `HKStatisticsCollectionQuery`
valida la combinación tipo/opciones — y esa excepción sin capturar mata el
proceso. Esto ocurría en el arranque porque `AppBootstrapper.preloadData()`
llama a `fetchCardioSummary` en el paso 4 del splash.

### Fix

`fetchDailyQuantities` ahora comprueba pertenencia a un `Set` explícito de
identificadores discretos (`.heartRate`, `.heartRateVariabilitySDNN`,
`.restingHeartRate`, `.walkingHeartRateAverage`) en vez de dos comparaciones
sueltas — cubre todos los tipos de cardio realmente usados en la app.

### Nota sobre trabajo concurrente

Durante esta sesión se detectó una **segunda sesión de IA (DeepSeek Harness)
editando este mismo repositorio en paralelo**, en la misma máquina, sin
coordinación con esta sesión — de ahí que varios ficheros (HealthAgent,
NotificationManager, ContentView, RemindersView, SecondaryViews,
MedicationDetailView, LabHistoryStore.swift nuevo, DoctorVisitsView.swift
nuevo, DashboardView, ProfileView, project.yml) fueran cambiando de contenido
en mitad de esta sesión. Solo se comitea aquí el fix aislado de
HealthKitManager.swift, verificado de forma independiente vía el crash log;
el resto de cambios en curso se deja para que el usuario decida cómo
consolidarlos.

### ✅ Verificación

- [x] Root cause confirmado leyendo el `.ips` real (no es una suposición)
- [x] `xcodebuild build` (simulador) — BUILD SUCCEEDED con el fix aplicado

---

## 🛠️ Sesión 6 (2026-08-24) — Sin icono, sin splash, sin fondos: bug real en xcodegen

El usuario confirmó que, tras los fixes de la sesión 4 (AppIcon.png,
UILaunchScreen), la app seguía sin mostrar icono, splash ni fondos, y
además "no iba fina". Se investigó a fondo antes de tocar nada.

### Causa raíz

**La clave `resources:` del target en `project.yml` no genera ninguna fase
"Copy Bundle Resources" en el `.xcodeproj`**, con xcodegen 2.45.3 *y*
2.46.0 (se actualizó de una a otra para descartar una regresión de
versión — el bug persiste en ambas). Verificado de tres formas:

1. `grep "PBXResourcesBuildPhase"` sobre el `.pbxproj` generado: 0 resultados.
2. `Assets.xcassets` no aparece en ninguna parte del `.pbxproj` (ni como
   referencia de fichero, ni en ningún grupo).
3. Reproducido en un proyecto XcodeGen mínimo y aislado, fuera de este
   repo, con el `resources:` de libro tal cual lo documenta XcodeGen —
   mismo resultado: 0 recursos incluidos.
4. Confirmado en el `.app` compilado: sin `Assets.car`, sin ningún `.png`/
   `.jpeg`, sin `Localizable.xcstrings`.

Esto explicaba a la vez la falta de icono, splash y fondos: **ningún**
recurso del catálogo de assets llegaba nunca al bundle, en ningún build
anterior — los fixes de icono/launch screen de la sesión 4 eran correctos
a nivel de configuración, pero nunca se empaquetaron.

### Workaround verificado

Declarando la misma carpeta de recursos (`Neximed/Resources`) como una
entrada más de `sources:` (en vez de en la clave separada `resources:`),
xcodegen SÍ la detecta y enruta correctamente — los `.swift` van a
`Sources` y todo lo demás (`Assets.xcassets`, `Images/*.jpeg`,
`Localizable.xcstrings`) va a `Resources`, exactamente igual que si el
`resources:` funcionara. Aplicado en `project.yml` con un comentario
explicando el porqué (para que nadie lo revierta sin saber que
`resources:` está roto en esta instalación).

### Verificación

- [x] `PBXResourcesBuildPhase` presente y con 3+ entradas tras el fix
- [x] `.app` compilado contiene `Assets.car` (28.7 MB) + todos los `.jpeg`/`.png` individuales + `Localizable.xcstrings`
- [x] Icono verificado extrayendo `AppIcon60x60@2x.png` del bundle compilado: arte a sangre completa, sin marco blanco
- [x] Lanzada en simulador (`xcrun simctl`): splash a medida con imagen, título y barra de progreso — visible desde el primer frame
- [x] La app llega al Dashboard con contenido real sin crashear (fix de la sesión 5 + este, juntos)
- [x] Log de consola durante el arranque: sin avisos de "Publishing changes from background threads", ciclos de AttributeGraph, ni hangs
- [x] `xcodebuild build` (simulador), `xcodebuild build` (dispositivo arm64) y `xcodebuild archive` (Release) — los tres BUILD/ARCHIVE SUCCEEDED con el fix

### Sobre "no va fina"

Gran parte de esa sensación probablemente venía de este mismo bug: cada
`Image("...")` de la app fallaba en silencio (catálogo de assets ausente),
sin `AccentColor` cargado para tintar controles, con la vista de fondo del
splash vacía durante toda la carga. Con los recursos ya empaquetados, no
se han detectado avisos de rendimiento en consola en este arranque. Una
medición de fluidez real (FPS, hitches) requeriría Instruments en
dispositivo físico, fuera del alcance de este entorno.

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

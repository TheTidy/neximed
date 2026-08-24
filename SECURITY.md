# 🔐 Neximed — Seguridad y Privacidad de la App

> Documento técnico de las medidas de seguridad implementadas para proteger los
> datos de salud del usuario cuando el dispositivo cambia de manos.

---

## 🎯 El problema

Neximed almacena datos de salud **extremadamente sensibles**: analíticas de sangre,
medicación, síntomas, contacto de emergencia, constantes de HealthKit (FC, HRV,
sueño) y conversaciones con el agente. **No hay login** (por diseño: es 100%
on-device y sin cuentas). Si alguien coge el móvil desbloqueado, tendría acceso
a todos esos datos.

---

## 🛡️ Medidas implementadas

### 1. Bloqueo biométrico (Face ID / Touch ID / código)

- **SecurityManager.swift** (nuevo): usa ``LocalAuthentication`` (LAContext)
  con ``.deviceOwnerAuthentication`` — Face ID o Touch ID, con fallback al código
  del dispositivo.
- **AppLockView.swift** (nuevo): pantalla de bloqueo con la estética de la app
  (gradiente, candado, botón de desbloqueo).
- **Bloqueo automático**: en ``ContentView``, al pasar a ``.background`` o
  ``.inactive`` (cambiar de app, apagar pantalla, abrir el centro de control),
  la app se bloquea inmediatamente.
- Al volver a ``.active``, la ``AppLockView`` cubre la interfaz y pide biometría.
- El desbloqueo es **por sesión**: al reabrir, vuelve a pedir.

### 2. Redacción de contenido sensible (capturas y App Switcher)

Con ``.privacySensitive()`` (SwiftUI, iOS 17+), iOS redacta automáticamente esas
vistas en: capturas de pantalla, grabaciones de pantalla y la miniatura del
App Switcher. Aplicado a:

| Vista | Qué protege |
|-------|-------------|
| DashboardView — metricsGrid | FC reposo, HRV, sueño, pasos |
| DashboardView — sleepGoalRing | Anillo de objetivo de descanso |
| SecondaryViews — labResultCard | Valores de analíticas de sangre |
| AgentChatView — mensajes | Conversaciones con datos de salud |

### 3. Cifrado de datos en reposo (File Protection)

El contenedor SwiftData se crea con:
``protectionType: .completeUntilFirstUserAuthentication``

→ Los datos de la base de datos **solo son accesibles tras el primer desbloqueo
del dispositivo**. Si el iPhone está apagado o bloqueado con cifrado, los datos
de Neximed no se pueden leer (ni siquiera con extracción forense del archivo).

### 4. Sin datos fuera del dispositivo

- ``cloudKitDatabase: .none`` — SwiftData no sincroniza nada en la nube
- ``requiresOnDeviceRecognition = true`` — el dictado de voz no sale del iPhone
- IA 100% on-device (FoundationModels) — los prompts nunca van a un servidor
- Sin cuentas, sin telemetría, sin servidores propios

---

## 🔍 Cómo funciona el flujo de bloqueo

``````
Usuario usa la app (desbloqueada)
   │
   ▼  Pulsa el botón de inicio / cambia de app / apaga la pantalla
scenePhase → .background / .inactive
   │
   ▼  SecurityManager.lock()  → isLocked = true
   │
   ▼  ContentView .overlay → AppLockView cubre la interfaz
   │
   ▼  Usuario vuelve a la app (scenePhase → .active)
AppLockView pide Face ID / Touch ID / código
   │
   ├─ Éxito → isLocked = false → la app se muestra de nuevo
   └─ Fallo/cancelación → permanece bloqueada (con mensaje de error)
``````

---

## ⚠️ Comportamiento en el simulador

- El simulador **no tiene Face ID** activado por defecto: en *Features → Face ID*
  puedes simularlo.
- Si el simulador no tiene passcode, ``canEvaluatePolicy`` devuelve false y la app
  se desbloquea automáticamente (comportamiento seguro: en un iPhone real con
  passcode esto nunca ocurre).

---

## 📋 Checklist de verificación en el build real

- [ ] Face ID/Touch ID configurado en el iPhone físico
- [ ] Al pulsar inicio, la app se bloquea al volver
- [ ] La miniatura del App Switcher muestra la pantalla de bloqueo (no los datos)
- [ ] Las capturas de pantalla redactan métricas y analíticas
- [ ] Desbloqueo con Face ID funciona y con código de respaldo también
- [ ] El Info.plist/entitlements no requiere nada extra para LocalAuthentication

---

## 🔗 Fuentes oficiales

- LocalAuthentication / LAContext: https://developer.apple.com/documentation/localauthentication
- FileProtectionType.completeUntilFirstUserAuthentication: https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication
- SwiftUI privacySensitive(_:): https://developer.apple.com/documentation/SwiftUI/View/privacySensitive(_:)
- SwiftData ModelConfiguration: https://developer.apple.com/documentation/swiftdata/modelconfiguration
- Apple Forum — Data Protection and SwiftData Containers: https://developer.apple.com/forums/thread/773180
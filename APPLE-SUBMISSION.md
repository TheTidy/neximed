# 🍏 Neximed — Base para Subir a App Store / TestFlight

> Documento maestro con TODO el texto y configuración listos para App Store Connect.
> Copia y pega cada sección en su campo correspondiente.

---

## 1. DATOS DE LA APP (App Store Connect → Mis Apps → Nueva App)

| Campo | Valor |
|-------|-------|
| Plataforma | iOS |
| Nombre | Neximed |
| Idioma principal | Español (ES) |
| Bundle ID | com.neximed.app |
| SKU | neximed-001 |
| Categoría | Salud y bienestar |
| Subcategoría | (opcional) |
| Edad mínima | 4+ |

---

## 2. DESCRIPCIÓN (campo Description — máx 4000 caracteres)

### Español
``````
Neximed es tu cuaderno clínico personal: organiza tus datos de salud de Apple Watch, tus analíticas de laboratorio, tu medicación y tus síntomas, y prepara tu próxima consulta médica en un dossier PDF de 1 página.

TODO 100% PRIVADO Y ON-DEVICE
• Todos tus datos se procesan y almacenan únicamente en tu dispositivo.
• Sin cuentas, sin servidores, sin publicidad. Neximed no puede ver tus datos: solo tú.

DICTADO POR VOZ CON IA
• Habla con naturalidad: Neximed limpia tu redacción, extrae las etiquetas clave (síntoma, intensidad, contexto) y guarda tu registro en un toque.
• El reconocimiento y la inteligencia artificial funcionan en tu iPhone, sin conexión.

ESCÁNER DE ANALÍTICAS
• Fotografía tu analítica o importa el PDF: extrae y organiza más de 25 biomarcadores.
• Compara tus valores con los rangos de referencia del laboratorio (informativo).

BOTIQUÍN INTELIGENTE
• Registra tu medicación y suplementos con dosis y horarios.
• Recordatorios de toma y registro de efectos secundarios.
• Entiende tu diagnóstico con explicaciones en lenguaje sencillo (educativo).

DOSSIER PARA TU MÉDICO
• Genera un PDF clínico de 1 página con tus constantes, medicación, alergias y preguntas preparadas.
• Exporta todos tus datos en CSV o JSON para compartirlos con tu profesional.

MÁS FUNCIONALIDADES
• Perfil completo: datos clínicos, alergias alimentarias (14 alergenos UE), dieta, trabajo y hábitos digitales.
• Correlaciones observacionales entre tu sueño, actividad y recuperación.
• Seguimiento de peso con tendencia.
• Check-in diario de bienestar.
• Bloqueo con Face ID / Touch ID para proteger tu información.
• Español e inglés.

Neximed es una herramienta de organización personal de datos de salud. No proporciona diagnósticos ni tratamientos y no sustituye el criterio de un profesional médico.
``````

### English (para ampliar alcance)
``````
Neximed is your personal clinical notebook: organize your Apple Watch health data, lab results, medications and symptoms, and prepare your next doctor visit with a 1-page PDF dossier.

100% PRIVATE AND ON-DEVICE
• All your data is processed and stored only on your device.
• No accounts, no servers, no ads. Neximed cannot see your data: only you can.

VOICE-FIRST WITH AI
• Speak naturally: Neximed cleans your text, extracts key tags (symptom, intensity, context) and saves your record in one tap.
• Speech recognition and AI run on your iPhone, offline.

LAB RESULT SCANNER
• Photograph your lab report or import a PDF: extract and organize 25+ biomarkers.
• Compare your values against the lab reference ranges (informational).

SMART MEDICATION
• Log your medications and supplements with doses and schedules.
• Dose reminders and side effect tracking.
• Understand your diagnosis with plain-language explanations (educational).

DOSSIER FOR YOUR DOCTOR
• Generate a 1-page clinical PDF with your vitals, medication, allergies and prepared questions.
• Export all your data as CSV or JSON to share with your professional.

Neximed is a personal health data organization tool. It does not provide diagnoses or treatments and does not replace the judgment of a healthcare professional.
``````

---

## 3. NOTAS DE REVISIÓN (Review Notes — las MÁS importantes)

``````
Neximed is a personal health data organization tool. Key points for review:

1. 100% ON-DEVICE: All data (HealthKit, voice dictation, lab photos, AI) is processed and stored locally on the user's device. There are no servers, no accounts, no data collection, and no analytics. The app works fully offline.

2. NO MEDICAL ADVICE: The app does NOT diagnose, prescribe, or treat. It only organizes the user's own data and generates informational summaries. The AI assistant is explicitly instructed to never give medical advice and always recommend consulting a doctor. A disclaimer is shown in-app.

3. HEALTHKIT: The app reads health constants (resting heart rate, HRV, sleep, activity) and writes nutrition entries, only with the user's explicit consent. Data is never shared, sold, or used for advertising.

4. PRIVACY POLICY: Available at https://thetidy.github.io/neximed/privacy-policy/ (no sign-in required).

5. VOICE: Speech recognition uses on-device recognition (requiresOnDeviceRecognition = true). Audio is never uploaded.

6. AI (Apple Intelligence): When available (iOS 26+), the app uses Apple's on-device Foundation Models. On devices without support, the app gracefully degrades to a basic mode with local heuristics.

To test: open the app, complete onboarding, grant HealthKit access, and explore the tabs. The app is fully functional without Apple Intelligence (basic mode).
``````

---

## 4. CUESTIONARIO DE DATOS DE SALUD (App Privacy / Health Data)

App Store Connect te preguntará sobre datos de salud. Responde así:

| Pregunta | Respuesta |
|----------|-----------|
| ¿La app recopila datos de salud? | Sí (los gestiona en el dispositivo) |
| ¿Se vinculan a la identidad del usuario? | No |
| ¿Se usan para publicidad? | No |
| ¿Se usan para tracking? | No |
| ¿Se comparten con terceros? | No |
| ¿Se pueden eliminar? | Sí (borrar la app elimina todos los datos) |
| ¿Se envían datos fuera del dispositivo? | No — todo es on-device |

**Declaración de privacidad (App Privacy)** — respuestas a marcar:
- Health & Fitness: **Sí** (datos no vinculados a identidad, no usados para tracking)
- User Content: **No**
- Identifiers: **No**
- Purchase: **No**
- Location: **No**
- Contact Info: **No**
- Diagnostics: **No**

---

## 5. KEYWORDS (máx 100 caracteres, separadas por coma)

``````
salud, salud, medicina, doctor, médico, analíticas, laboratorio, síntomas, medicación, botiquín, dossier, HealthKit, Apple Watch, dictado, voz, frecuencia cardíaca, HRV, sueño, peso, bienestar, privacidad, clínico
``````

---

## 6. PANTALLAS PARA CAPTURAS (screenshots 6.7" — 1290x2796)

| # | Pantalla | Qué mostrar |
|---|----------|-------------|
| 1 | Dashboard | Métricas + anillo de sueño + recomendaciones |
| 2 | Dictado por voz | Onda + texto pulido + etiquetas |
| 3 | Dossier PDF | El informe de 1 página |
| 4 | Laboratorio | Biomarcadores + interpretación |
| 5 | Asistente | Chat con el agente |

**Fondo para las capturas**: Neximed/Resources/Images/AppStore/screenshot-backdrop.jpeg

---

## 7. VERSIÓN Y BUILD

| Campo | Valor actual |
|-------|-------------|
| Versión (CFBundleShortVersionString) | 1.0.0 |
| Build (CFBundleVersion) | 1 |
| Incrementar build | Cada subida a TestFlight: +1 (en project.yml: CURRENT_PROJECT_VERSION) |

---

## 8. CHECKLIST DE SUBIDA (orden exacto en tu Mac)

1. xcodegen generate
2. open Neximed.xcodeproj
3. Seleccionar Team de firma (Signing & Capabilities)
4. Cmd+B (compilar) → resolver errores
5. Product > Archive
6. Distribute App → App Store Connect → Upload
7. En App Store Connect: crear app con los datos de la sección 1
8. Pegar descripción (sección 2), notas de revisión (3), keywords (5)
9. Subir icono (AppIcon.png ya listo) y screenshots (sección 6)
10. Responder cuestionario de salud (sección 4)
11. Pegar URL de privacidad: https://thetidy.github.io/neximed/privacy-policy/
12. Añadir build de TestFlight → activar testers
13. Cuando esté listo → Enviar a revisión

---

## 9. RECORDATORIOS CRÍTICOS DE APPLE

- Apps de salud se revisan con lupa: el texto de la app NUNCA debe sugerir diagnóstico o tratamiento.
- HealthKit: prohibido usar datos para publicidad o venderlos.
- La IA on-device solo funciona en iPhone 15 Pro+ con iOS 26+; en el resto, Modo Básico.
- El simulador no puede probar HealthKit real, cámara ni IA: usa un iPhone físico.
- No necesitas entitlement especial para HealthKit básico (lectura de constantes + escritura de nutrición).
# 🧪 NEXIMED — HOJA DE SUBIDA A TESTFLIGHT (RELLENADA)

> Formulario completo, campo por campo, tal como aparece en App Store Connect.
> Solo copia y pega cada valor en su campo. Todo está pre-rellenado.

---

## PARTE 1 — CREAR LA APP EN APP STORE CONNECT

### Página: Mis Apps > + (botón arriba izquierda) > Nueva App

| Campo de la interfaz | Valor a introducir |
|---------------------|--------------------|
| Plataformas | iOS |
| Nombre | Neximed |
| Idioma principal | Español (ES) |
| Bundle ID | com.neximed.app (seleccionar del desplegable) |
| SKU | neximed-001 |
| Acceso | Completo |

> Si com.neximed.app no aparece en el desplegable: primero registra el Bundle ID en
> Certificates, Identifiers & Profiles > Identifiers > + > App IDs > App > com.neximed.app

---

## PARTE 2 — PESTAÑA GENERAL / APP INFORMATION

| Campo | Valor |
|-------|-------|
| Subtítulo | Tu cuaderno clínico personal |
| Categoría | Salud y bienestar |
| Edad mínima | 4+ |
| URL de política de privacidad | https://thetidy.github.io/neximed/privacy-policy/ |
| Marketing URL | (opcional, vacío) |
| Support URL | https://github.com/TheTidy/neximed |
| Clasificación de contenido | Sin restricciones (desmarcar todo) |

---

## PARTE 3 — PESTAÑA APP STORE / DESCRIPTION

### Descripción (ES) — copiar y pegar completo:
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

### Keywords (ES, máx 100 caracteres):
``````
salud, medicina, doctor, analíticas, laboratorio, síntomas, medicación, botiquín, dossier, HealthKit, Apple Watch, dictado, voz, corazón, sueño, peso, bienestar, privacidad
``````

### Notas de versión (What's New):
``````
Primera versión de Neximed: dictado por voz con IA on-device, escáner de analíticas, botiquín con recordatorios, dossier médico en PDF y perfil completo de salud. Todo 100% privado y en tu dispositivo.
``````

---

## PARTE 4 — PESTAÑA APP STORE / SCREENSHOTS

Subir 5 capturas 6.7 pulgadas (1290x2796), en este orden:
1. Dashboard con métricas y anillo de sueño
2. Dictado por voz con onda y texto pulido
3. Dossier PDF de 1 página
4. Laboratorio con biomarcadores
5. Asistente conversacional

Icono: subir AppIcon.png (ya generado, 1024x1024) — en Assets.xcassets

---

## PARTE 5 — APP PRIVACY (Cuestionario de datos)

Responder en 'App Privacy' de la app:

| Pregunta | Respuesta |
|----------|-----------|
| ¿Recopila datos? | Sí — Health & Fitness (datos no vinculados a identidad) |
| ¿Vinculados a identidad? | No |
| ¿Usados para tracking? | No |
| ¿Compartidos con terceros? | No |
| ¿Se pueden eliminar? | Sí (borrar la app elimina todo) |

Marcar únicamente: Health & Fitness > Health (no vinculado a identidad, no usado para tracking)

---

## PARTE 6 — TESTFLIGHT (la parte de subida)

1. En tu Mac, con el proyecto abierto:
   - Product > Archive (destino: Any iOS Device)
   - Distribute App > App Store Connect > Upload
2. En App Store Connect > Mis Apps > Neximed > TestFlight:
   - El build aparece en 'iOS Builds' tras 5-15 min de procesado
   - Pestaña 'Test Information' > What to Test:
``````
Probar el flujo completo: onboarding, conectar HealthKit, dictar un síntoma por voz, generar el dossier PDF y compartirlo, registrar una comida, añadir un medicamento con recordatorio, y exportar datos en CSV. La app funciona completa sin Apple Intelligence (modo básico).
``````
   - Export Compliance: responder 'No' (no usa cifrado propio)
3. Testers internos: Añadir > tu Apple ID
4. Activar el build (botón + junto al build)

---

## PARTE 7 — NOTAS PARA LA REVISIÓN (si subes a review)

``````
Neximed is a personal health data organization tool. Key points:
1. 100% ON-DEVICE: all data (HealthKit, voice, lab photos, AI) stays on the user's device. No servers, accounts, or analytics.
2. NO MEDICAL ADVICE: the app never diagnoses or prescribes; it only organizes the user's own data. The AI assistant always recommends consulting a doctor. In-app disclaimer shown.
3. HEALTHKIT: reads constants and writes nutrition only with explicit user consent. Data never shared, sold, or used for ads.
4. PRIVACY POLICY: https://thetidy.github.io/neximed/privacy-policy/
5. VOICE: on-device recognition (requiresOnDeviceRecognition = true). Audio never uploaded.
6. AI: uses Apple's on-device Foundation Models when available (iOS 26+); gracefully degrades to basic mode otherwise.
To test: complete onboarding, grant HealthKit, and explore the tabs. Fully functional without Apple Intelligence.
``````

---

## CAMPO QUE DEBES COMPLETAR TÚ (no puede ir pre-rellenado)

| Campo | Por qué |
|-------|---------|
| Team de firma en Xcode | Es tu cuenta de desarrollador personal |
| Credenciales de App Store Connect | Son tu login de Apple |
| El build compilado | Solo se genera en tu Mac con Xcode |
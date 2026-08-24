# 👤 Neximed — Perfil Completo del Usuario

> Documento del perfil ampliado: datos demográficos, clínicos, nutrición,
> trabajo, hábitos digitales y contacto de emergencia. El perfil contextualiza
> TODAS las respuestas del agente y el dossier médico.

---

## 📋 Campos del perfil (UserProfile ampliado)

### Datos demográficos
- Fecha de nacimiento (edad calculada automáticamente)
- Sexo: Hombre / Mujer / Prefiero no decirlo
- Altura (cm) y Peso (kg) → **IMC calculado** (orientativo)

### Ficha clínica
- Grupo sanguíneo (A+, A-, B+, B-, AB+, AB-, 0+, 0-)
- **Patologías previas** (ej: sarcoidosis, hipotiroidismo, asma)
- Alergias
- Medicación actual
- Tabaco: Nunca / Exfumador / Fumador
- Alcohol: Nunca / Ocasional / Semanal / Diario

### Nutrición y dieta
- Tipo de dieta: Omnívora / Mediterránea / Vegetariana / Vegana / Keto / Sin gluten
- Restricciones alimentarias (ej: sin lactosa, sin gluten, baja en sodio)
- Comidas al día (1-6)
- Agua diaria aprox. (litros)

### Trabajo y rutina
- **Horario laboral**: Diurno / Nocturno / Turnos rotativos / Teletrabajo / Jubilado
- Horas de trabajo semanales
- Ritmo de sueño: Madrugador / Noctámbulo / Irregular
- Actividad física: Sedentario / Ligero / Moderado / Intenso

### Hábitos digitales (horas de pantalla)
- **Auto-reporte** (funciona siempre): horas de pantalla estimadas
- **Screen Time API** (automático, requiere aprobación de Apple):
  entitlement ``com.apple.developer.family-controls`` — comentado en entitlements
  hasta que se conceda

### Contacto de emergencia (Ficha ICE)
- Nombre y teléfono del contacto de emergencia

---

## 🔗 Cómo se usa el perfil

1. **Agente de IA** (``HealthAgent.buildSystemPrompt``): el ``lifestyleSummary``
   (edad, sexo, IMC, patologías, dieta, trabajo, pantalla...) se inyecta en el
   prompt del sistema → las respuestas son contextuales (ej: un noctámbulo con
   turnos rotativos recibe análisis de sueño adaptado).
2. **Dossier PDF** (``MedicalReportExporter``): el perfil se incluye en la cabecera
   del informe para el médico (Ficha ICE + antecedentes).
3. **Modo Básico** (sin IA): ``localDoctorPrep`` usa los datos del perfil para
   generar observaciones contextuales.

---

## 📱 Vistas

- **ProfileView.swift** (nueva): formulario completo en la pestaña Perfil (6ª pestaña)
- Guardado inmediato en SwiftData al editar cada campo

---

## ⚠️ Screen Time API — requisitos

La medición AUTOMÁTICA de horas de pantalla usa la Screen Time API de Apple
(FamilyControls + DeviceActivity), que requiere:

1. Entitlement ``com.apple.developer.family-controls`` — **aprobación especial**
   de Apple (solicitud en developer.apple.com, revisión manual).
2. Extensión ``DeviceActivityReportExtension`` para renderizar el informe.
3. El usuario debe conceder acceso en Ajustes → Screen Time.

Hasta que se apruebe, la app usa el **auto-reporte** (el usuario indica sus horas
de pantalla), que funciona sin requisitos adicionales.
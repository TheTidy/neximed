# 📱 Neximed — Funcionalidades Completas

> Inventario de TODAS las funcionalidades de la app, organizadas por módulo.
> Sin funciones perdidas ni escondidas: todo está documentado y conectado.

---

## 🗂️ Módulos de lógica

| Módulo | Archivo | Funcionalidad |
|--------|---------|---------------|
| HealthKit | HealthKitManager.swift | Constantes, sueño, nutrición, actividad + CACHE de precarga |
| IA | HealthAgent.swift + AgentPrompts.swift | Refinamiento de voz, chat, preparación de consulta, laboratorio |
| Voz | VoiceDictationManager.swift | Dictado on-device multiidioma (es/en) |
| OCR | LabScanner.swift | Escáner de analíticas (foto y PDF) con 25 biomarcadores |
| Comida | FoodAnalyzer.swift + FoodDatabase.swift | Análisis por foto + base curada de 35 alimentos |
| Seguridad | SecurityManager.swift | Face ID / Touch ID / código |
| Screen Time | ScreenTimeManager.swift | Horas de pantalla (auto-reporte + API pendiente de aprobación) |
| Recordatorios | NotificationManager.swift | Medicación, hidratación, cita, check-in diario |
| Correlaciones | CorrelationAnalyzer.swift | Patrones sueño↔HRV, pasos↔FC, sueño↔pasos |
| Recomendaciones | WellnessRecommendations.swift | Datos vs. objetivos (seguras, sin diagnóstico) |
| Exportación | DataExporter.swift | CSV y JSON de todos los datos |
| Idioma | LanguageManager.swift | Español e inglés (detección + manual) |
| Arranque | AppBootstrapper.swift | Splash con barra de progreso real |

---

## 🖥️ Vistas de la app (pestañas y modales)

| Vista | Pestaña/Modal | Contenido |
|-------|--------------|----------|
| DashboardView | Pestaña 1 | Métricas, anillo de sueño, gráficas, recomendaciones, síntomas, dossier PDF |
| AgentChatView | Pestaña 2 | Chat con el agente (IA o modo básico) |
| NutritionView | Pestaña 3 | Foto con IA, código de barras, registro manual (FoodLogView), macros |
| LabsView | Pestaña 4 | Escáner de analíticas (foto/PDF), interpretación, empty state |
| TrendsView | Pestaña 5 | Gráficas, CORRELACIONES automáticas, PESO con tendencia |
| ProfileView | Pestaña 6 | Perfil completo, idioma, RECORDATORIOS, EXPORTACIÓN, ICE |
| OnboardingView | Modal | Carrusel con 3 ilustraciones + nombre |
| VoiceDictationSheet | Modal | Dictado con ilustración, fondo y error visible |
| AppLockView | Overlay | Bloqueo biométrico |
| SplashScreenView | Arranque | Barra de progreso real (AppBootstrapper) |
| RemindersView | Enlace desde Perfil | Gestión de recordatorios |
| FoodLogView | Sheet desde Nutrición | Búsqueda y registro manual de comida |

---

## 📊 Datos que recopila y calcula

### De HealthKit (Apple Watch / iPhone)
- Pasos, calorías activas, ejercicio, distancia
- FC reposo, HRV, FC media
- Sueño (total, REM, profundo, core)
- Nutrición (kcal, proteína, carbos, grasa)

### Del perfil del usuario
- Demográficos: edad, sexo, altura, peso → IMC
- Clínicos: grupo sanguíneo, patologías, alergias, medicación, tabaco, alcohol
- Nutrición: dieta, restricciones, comidas/día, agua
- Trabajo: horario (diurno/nocturno/turnos), horas, sueño, actividad
- Digital: horas de pantalla

### Registro manual
- Peso (WeightEntry) con tendencia gráfica
- Comidas (FoodLogView + base curada)
- Síntomas por voz
- Check-in diario (DailyCheckIn — modelo listo)

### Derivados (calculados on-device)
- IMC (del perfil)
- Edad (de la fecha de nacimiento)
- Recomendaciones (datos vs. objetivos)
- Correlaciones de Pearson (sueño↔HRV, pasos↔FC, sueño↔pasos)

---

## ⚠️ Notas de integridad

- DailyCheckIn: modelo creado y registrado en el schema, pero la UI de check-in
  se conectará cuando se programe el recordatorio (el recordatorio ya existe).
- Screen Time automático: pendiente del entitlement family-controls de Apple.
- La base de alimentos tiene 35 alimentos curados; ampliable fácilmente.
---

## ⚠️ Sistema de Alergias Alimentarias (crítico)

Implementado como capa de seguridad transversal:

| Componente | Archivo | Función |
|------------|---------|---------|
| Allergen (17 tipos) | Models/Allergen.swift | Los 14 alergenos obligatorios de la UE (Reglamento 1169/2011) + lactosa e histamina |
| foodAllergens | UserProfile | Selección del usuario en el perfil |
| Etiquetado de alimentos | FoodDatabase | Cada alimento declara sus alergenos (gluten, lácteos, pescado, frutos secos...) |
| Detección unsafeAllergens | FoodDatabase | Cruzar alergenos del alimento vs. los del usuario |
| Alerta al registrar | FoodLogView | Aviso rojo + confirmación antes de registrar |
| IA contextual | HealthAgent | El agente conoce los alergenos del paciente |
| Dossier PDF | MedicalReportExporter | Alergenos alimentarios destacados en rojo |
| Exportación | DataExporter | Incluidos en CSV y JSON |

### Flujo de seguridad

1. Usuario marca alergenos en Perfil (chips con iconos)
2. Al buscar un alimento, FoodLogView muestra aviso rojo si contiene alguno
3. Al pulsar registrar, alerta de confirmación: 'Registrar de todos modos' o 'Cancelar'
4. El dossier médico y el agente reflejan los alergenos

### Alimentos etiquetados con alergenos
- Gluten: pan (integral/blanco), avena, pasta
- Lácteos + lactosa: leche, yogur, quesos
- Pescado: salmón, atún
- Huevos: huevo
- Soja: tofu
- Frutos de cáscara: almendras, nueces
- Cacahuetes: cacahuetes
- Apio: apio
- Sésamo: garbanzos (tahini)

### Nota legal
- Basado en el Reglamento (UE) 1169/2011 sobre información alimentaria
- La base de datos es orientativa: los alimentos procesados pueden contener
  alergenos no listados (trazas) — siempre se recomienda verificar la etiqueta.

## 🍎 Base de datos de alimentos ampliada (137 alimentos)

- **137 alimentos curados** on-device, organizados en 10 categorías
- **67 alimentos etiquetados con alergenos** (los 14 de la UE + lactosa)
- Búsqueda con tolerancia a acentos ('cafe' encuentra 'café')
- Filtro por dieta: ``search(query, diet:)`` respeta vegana/vegetariana (isVegan/isVegetarian)
- Macros por porción típica calculados automáticamente

## 😊 Check-in diario de bienestar (DailyCheckIn)

- **DailyCheckInView**: ánimo (4 niveles con emoji), energía (3 niveles),
  calidad de sueño (1-5 estrellas) y notas — guardado en SwiftData
- **Botón en el Dashboard**: 'Check-in de bienestar' junto a Dictar y Dossier
- **Recordatorio programable** desde RemindersView (notificación local diaria)
- Modelo ya registrado en el schema SwiftData

## 💊 Botiquín avanzado (medicación)

### Dosis y tomas
- ``dosePerIntake``: dosis exacta por toma (ej: 50 mcg, 1 comprimido)
- ``intakeTimes``: horarios de toma en formato HH:mm (múltiples al día)
- ``MedicationDoseLog``: registro de tomas confirmadas (tomada/omitida + motivo)

### Recordatorios de tomas
- Por medicamento: cada horario programa una notificación local diaria
- La notificación incluye el nombre y la dosis (ej: 'Es hora de tu dosis: 50 mcg')
- Toggle por medicamento para activar/desactivar
- Identificadores únicos (med-UUID-hora) para cancelar sin afectar a otros

### Efectos secundarios
- ``sideEffects``: posibles (según prospecto) — se muestran con icono informativo
- ``experiencedSideEffects``: los que el usuario ha experimentado (se muestran en
  naranja en la lista y en el dossier)
- Añadir con un campo rápido

### Explicación de diagnóstico (educativa y segura)
- ``explainDiagnosis``: explica en lenguaje sencillo un diagnóstico dado por el médico
- Prompt con reglas estrictas: NO cuestiona al médico, NO da tratamiento, sugiere
  preguntas para SU médico, aclara que es informativo
- Fallback determinista si no hay IA
- Acceso desde el Botiquín: 'Entender mi diagnóstico'

### Vistas
- MedicationListView (Botiquín): lista + añadir + accesos
- MedicationDetailView: dosis, horarios, recordatorio, efectos, historial de tomas
- DiagnosisExplanationView: explicación educativa del diagnóstico
- Acceso desde el Perfil (sección Botiquín)

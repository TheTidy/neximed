# 📱 Neximed — Checklist de Publicación en App Store

> Documento de control para llevar la app desde el código hasta la App Store.
> Marca cada casilla con ``[x]`` cuando esté completada.

---

## ✅ FASE 0 — Requisitos previos

- [ ] **Cuenta de desarrollador Apple** (99 USD/año) en [developer.apple.com](https://developer.apple.com)
- [ ] **Mac con Xcode 26+** (para FoundationModels / Apple Intelligence)
- [ ] **XcodeGen instalado**: ``brew install xcodegen``
- [ ] **Bundle ID registrado** en App Store Connect: ``com.neximed.app``
- [ ] **iPhone físico para pruebas** (HealthKit y voz no funcionan completos en simulador)

---

## 🥇 FASE A — Build Verde

1. En la raíz del proyecto (tu Mac): ``xcodegen generate``
2. ``open Neximed.xcodeproj`` → selecciona tu **Team** de firma
3. Compila con **⌘B** y corrige los warnings/errores que surjan
4. Prueba en dispositivo real:
   - [ ] Dashboard carga constantes de HealthKit
   - [ ] Dictado por voz transcribe y guarda
   - [ ] Escáner OCR de analítica funciona
   - [ ] Generación de PDF → ShareSheet comparte el dossier
   - [ ] En un iPhone **sin** Apple Intelligence la app funciona en "Modo Básico"

---

## 📱 FASE B — Material App Store

- [ ] **Icono**: generar con PROMPT 1 de ``prompts.md`` → guardar como
      ``Neximed/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`` (1024×1024, sin texto)
- [ ] **Banner feature 16:9** (PROMPT 3) para la ficha de App Store
- [ ] **Fondos de screenshots** (PROMPT 7) para 3-6 capturas en 6.7"
- [ ] Capturar screenshots reales:
      1. Dashboard con constantes y gráficas
      2. Dictado por voz (onda + texto pulido)
      3. Dossier PDF de 1 página
      4. Laboratorio con marcadores escaneados
      5. Asistente conversacional
- [ ] **Política de privacidad pública** (obligatorio con HealthKit):
      subir a GitHub Pages / Notion y copiar la URL

---

## 🧪 FASE C — TestFlight

- [ ] Subir build: Xcode → *Product > Archive* → *Distribute App* → TestFlight
- [ ] Añadir testers internos (máx 100 usuarios)
- [ ] Probar la instalación desde TestFlight en 2-3 dispositivos reales
- [ ] Validar que **no se sube ningún dato personal** (todo on-device):
      revisar en Ajustes → Privacidad que no hay actividad de red sospechosa
- [ ] Testear el flujo completo: HealthKit → dictado → dossier → exportar

---

## 🏛️ FASE D — App Store Connect y Revisión

- [ ] Rellenar ficha: nombre "Neximed", subtítulo, categoría **Salud y bienestar**
- [ ] **Cuestionario de datos de salud**: responder con veracidad
      (la app NO usa datos para publicidad ni los vende)
- [ ] Edad mínima: 4+, clasificación de contenido: sin restricciones
- [ ] Subir screenshots, icono y política de privacidad
- [ ] **Notas para la revisión** (importante para apps de salud):
      explicar que es una herramienta de organización personal,
      que NO diagnostica ni prescribe, y que todo es on-device
- [ ] Enviar a revisión → esperar 24-72h

---

## 🚀 FASE E — Post-Publicación

- [ ] Verificar disponibilidad en la App Store
- [ ] Monitorizar reseñas y crashes (Xcode Organizer / App Store Connect)
- [ ] Planificar **v1.1 (Hito C)**: comparativa longitudinal, ficha ICE, App Intents Siri

---

## ⚠️ Recordatorios clave para revisión de Apple

1. **Apps de salud** se revisan con lupa: evita cualquier lenguaje que sugiera diagnóstico o tratamiento.
2. **HealthKit**: Apple prohíbe usar los datos para publicidad o venderlos a terceros.
3. **Privacidad**: todas las descripciones de uso ya están en el Info.plist — no cambies su redacción de forma que oculte el propósito.
4. **FoundationModels**: si el dispositivo no lo soporta, la app debe degradarse (ya implementado con ``aiAvailable``).
5. **Sin servidores**: la app es 100% on-device — refuerza esto en las notas de revisión.

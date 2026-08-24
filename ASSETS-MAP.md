# 🖼️ Neximed — Mapa de Assets Gráficos

> Inventario de las imágenes generadas (de promptsgemini.md), renombradas y
> organizadas en el proyecto. Estado: integradas en la app.

---

## Estructura

Neximed/Resources/
  Assets.xcassets/  <- LOS QUE USA LA APP (image sets)
    AppIcon.appiconset/AppIcon.png   (icono 1024x1024 PNG)
    AccentColor.colorset/  (Nexus Cyan #00D2FF)
    onboarding-1-voice.imageset
    onboarding-2-scanner.imageset
    onboarding-3-dossier.imageset
    illustration-voice.imageset
    illustration-labs.imageset
    illustration-dossier.imageset
    empty-labs.imageset
    empty-symptoms.imageset
    empty-medications.imageset
    background-global.imageset
    background-voice-modal.imageset
    splash-centerpiece.imageset
  Images/  <- ORIGINALES organizados por categoria
    Onboarding/  Illustrations/  EmptyStates/
    Backgrounds/  Splash/
    AppStore/  (para App Store Connect, no van en la app)

---

## Donde se usa cada imagen

| Imagen (set) | Uso en la app | Vista |
|--------------|---------------|-------|
| AppIcon.png | Icono de la app (1024x1024 PNG) | App Store + Home |
| onboarding-1-voice | Pagina 1 del carrusel de bienvenida | OnboardingView |
| onboarding-2-scanner | Pagina 2 del carrusel | OnboardingView |
| onboarding-3-dossier | Pagina 3 + campo de nombre | OnboardingView |
| illustration-voice | Estado listo para grabar del dictado | VoiceDictationSheet |
| illustration-labs | Cabecera del escaner de analiticas | LabsView (scanCard) |
| illustration-dossier | (disponible para preparacion de consulta) | (pendiente) |
| empty-labs | Sin analiticas todavia | LabsView |
| empty-symptoms | Sin sintomas registrados | DashboardView |
| empty-medications | (disponible para el botiquin) | (pendiente) |
| background-voice-modal | Fondo ambiental del modal de voz (opacidad 0.12) | VoiceDictationSheet |
| background-global | (disponible como fondo alternativo) | (pendiente) |
| splash-centerpiece | (disponible para Launch Screen personalizada) | (pendiente) |

---

## Assets para App Store Connect (carpeta AppStore/)

| Archivo | Uso | Tamaño requerido |
|---------|-----|------------------|
| feature-banner.jpeg | Banner destacado de la ficha (opcional) | 3840x2160 (16:9) |
| screenshot-backdrop.jpeg | Fondo para los screenshots | 6.7 pulgadas (1290x2796) |
| icon-dark-mode.jpeg | Referencia del icono en modo oscuro | (referencia) |
| watch-complication.jpeg | Referencia complicacion Watch (futuro) | 1024x1024 |

> El original del icono esta respaldado en la raiz como
> Images-appstore-backup-icono-original.jpeg (2048x2048).

---

## Renombrado aplicado

Los nombres originales (con espacios, acentos y guiones largos) se renombraron
a kebab-case (onboarding-1-voice), el estandar para asset catalogs, evitando
problemas de escape en codigo y rutas.
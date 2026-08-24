# 🌍 Neximed — Sistema Multiidioma

> Cómo funciona el idioma en la app: detección automática, selección manual,
> voz adaptada y prompts de IA por idioma.

---

## 🎯 Estado actual (antes de esta sesión)

- 100% monolingüe en español
- Reconocimiento de voz fijado a es-ES
- 77 cadenas de UI hardcodeadas en español
- Prompts de IA hardcodeados en español

---

## ✅ Sistema implementado

### 1. LanguageManager (nuevo)

- Detecta el idioma del dispositivo automáticamente (Locale.preferredLanguages)
- Soporta: Español (es-ES) e Inglés (en-US)
- Permite selección manual persistida (UserDefaults)
- Notifica el cambio de idioma (neximedLanguageChanged)
- Ubicación: Localization/LanguageManager.swift

### 2. Voz adaptada al idioma (VoiceDictationManager)

- El reconocedor ya NO está fijado a es-ES: se crea con el locale de la app
- Fallback inteligente: si el idioma no está descargado, usa el primer
  idioma soportado por el dispositivo (SFSpeechRecognizer.supportedLocales)
- Al cambiar el idioma, el reconocedor se recrea automáticamente

### 3. IA multidioma (AgentPrompts + HealthAgent)

- Nuevo archivo AgentPrompts.swift con los textos de la IA en español e inglés:
  - System prompt (principios del asistente)
  - Prompt de refinamiento de dictado
  - Prompt de preparación de consulta médica
  - Prompt de interpretación de laboratorio
- Apple Intelligence responde en el idioma de la instrucción: al usar el
  prompt correcto, las respuestas salen en el idioma del usuario

### 4. String Catalog (Localizable.xcstrings)

- Formato moderno de localización de Xcode (reemplaza Localizable.strings)
- Idioma fuente: es; traducciones al inglés incluidas (35+ cadenas de la UI)
- project.yml declara developmentLanguage: es y knownRegions: en, es

### 5. Selector de idioma en Perfil

- Nueva sección 'Idioma / Language' en ProfileView con selector segmentado
- Al cambiar: persiste + recrea el reconocedor de voz + la IA usa el nuevo idioma

---

## 🔄 Flujo de idioma

1. Arranque: LanguageManager detecta el idioma del dispositivo
2. Voz: SFSpeechRecognizer se crea con ese locale (con fallback)
3. IA: AgentPrompts.Language.current selecciona los prompts correctos
4. UI: Xcode usa el String Catalog para traducir las cadenas
5. Usuario puede forzar idioma en Perfil → todo se actualiza al instante

---

## 🧪 Pasos restantes para la v1.0

- [ ] Completar el String Catalog con las 77 cadenas de UI (las más importantes ya están)
- [ ] Usar String(localized:) en las vistas nuevas (ProfileView, etc.)
- [ ] Añadir más idiomas cuando el mercado lo pida (catalán, francés, alemán...)
- [ ] Verificar con Xcode: Product > Export Localizations

---

## 🔗 Fuentes oficiales

- SFSpeechRecognizer.supportedLocales(): https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportedlocales()
- Supporting languages and locales with Foundation Models: https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- WWDC25 - Explore localization with Xcode: https://developer.apple.com/videos/play/wwdc2025/225/
- String Catalogs: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
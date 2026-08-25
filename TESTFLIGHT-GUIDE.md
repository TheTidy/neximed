# 🧪 Neximed — Guía de TestFlight (paso a paso en tu Mac)

> Desde el código hasta que tus testers instalan la app. Sigue en orden.

---

## PASO 1 — Requisitos

- [ ] Cuenta de desarrollador Apple (99 USD/año): developer.apple.com
- [ ] Mac con Xcode 26
- [ ] XcodeGen instalado: brew install xcodegen
- [ ] El código en tu Mac (git clone o copia la carpeta)

---

## PASO 2 — Generar y abrir el proyecto

``````bash
cd <ruta-del-proyecto>
xcodegen generate
open Neximed.xcodeproj
``````

Si XcodeGen no está: brew install xcodegen

---

## PASO 3 — Configurar la firma (SIGNING)

1. En Xcode, selecciona el target **Neximed**
2. Pestaña **Signing & Capabilities**
3. Marca **Automatically manage signing** (ya está en project.yml)
4. En **Team**, selecciona tu cuenta de desarrollador (aparece al iniciar sesión en Xcode → Settings → Accounts)
5. Verifica que el **Bundle Identifier** sea: com.neximed.app

> Si no aparece tu Team: Xcode > Settings > Accounts > + > Apple ID > añade tu cuenta.

---

## PASO 4 — Compilar

1. Selecciona un simulador de iPhone (o tu iPhone físico conectado)
2. Cmd+B para compilar
3. Si hay errores → copia el mensaje exacto del primer error y pídelo por aquí para resolverlo

---

## PASO 5 — Probar localmente (recomendado antes de subir)

- Cmd+R para ejecutar en simulador
- **Modo Demo**: la app rellena datos ficticios en DEBUG (DemoDataSeeder) — ideal para ver la app llena
- Probar: navegación entre pestañas, perfil, botiquín, recordatorios, exportación
- Para cámara/HealthKit/voz reales: usar iPhone físico (conecta el cable o usa tu cuenta de desarrollador)

---

## PASO 6 — Subir a TestFlight

1. **Product > Archive** (asegúrate de que el destino es 'Any iOS Device', no un simulador)
2. En la ventana Archives: **Distribute App**
3. Selecciona **App Store Connect**
4. **Upload** (solo subir, no publicar aún)
5. Espera a que termine y confirme

---

## PASO 7 — Configurar App Store Connect

1. Ve a appstoreconnect.apple.com
2. **Mis Apps > + > Nueva App**
3. Rellena con los datos de APPLE-SUBMISSION.md (sección 1: nombre, bundle ID com.neximed.app, SKU, categoría)
4. En **TestFlight**: verás el build subido (tarda 5-15 min en procesarse)
5. **Testers internos**: Añade tu Apple ID como tester interno
6. En TestFlight > iOS > build > **Activar** (Export Compliance: responde No)
7. Los testers reciben invitación y pueden instalar con la app TestFlight

---

## PASO 8 — Probar desde TestFlight

- [ ] Instalar en 2-3 dispositivos reales (iPhone 13 y iPhone 15 Pro para comparar IA vs Modo Básico)
- [ ] Flujo completo: HealthKit → dictado → dossier → exportar
- [ ] Verificar privacidad: Ajustes > Privacidad > no hay actividad de red de Neximed

---

## SOLUCIÓN DE PROBLEMAS COMUNES

| Problema | Solución |
|----------|----------|
| 'No signing certificate found' | Xcode > Settings > Accounts > Manage Certificates > + > Apple Development |
| 'No profiles for com.neximed.app' | Automatically manage signing debería crearlos; revisa el Team |
| Archive gris / sin opción Archive | Destino debe ser 'Any iOS Device', no simulador |
| Build no aparece en TestFlight | Espera 5-15 min; comprueba que el build es Release |
| Export Compliance | Neximed no usa cifrado propio → responder 'No' |
| 'The app is missing required icon' | El AppIcon.png está listo en el asset catalog |

---

## RECORDATORIO

- Cada nueva subida a TestFlight requiere **incrementar el build**: en project.yml, CURRENT_PROJECT_VERSION: 2, 3, 4... (o Cmd+B automático si usas $(CURRENT_PROJECT_VERSION)).
- Los datos de la ficha (descripción, notas de revisión, keywords) están en APPLE-SUBMISSION.md.
- Política de privacidad URL: https://thetidy.github.io/neximed/privacy-policy/
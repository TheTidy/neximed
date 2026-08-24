# Neximed — Guia de Demo

> Como y cuando puedes mostrar la app. Hay DOS niveles de demo:

---

## 1. DEMO INTERACTIVA (YA DISPONIBLE - hoy mismo)

Archivo: DEMO.html (en la raiz del proyecto)

### Como abrirla
- En Windows/Mac: doble clic en DEMO.html (se abre en el navegador)
- En el movil: sube la carpeta del proyecto a cualquier hosting gratuito
  (GitHub Pages, Netlify Drop, Vercel) o envia DEMO.html + carpeta Neximed/Resources/Images

### Que muestra (14 pantallas navegables)
1. Splash con barra de carga
2-4. Onboarding con las 3 ilustraciones generadas
5. Dashboard con metricas, anillo de sueno y recomendaciones
6. Chat con el asistente (IA)
7. Preparacion de consulta medica
8. Dossier PDF de 1 pagina
9. Dictado por voz + texto pulido con etiquetas
10. Nutricion + busqueda de alimentos con aviso de alergenos
11. Laboratorio con biomarcadores e interpretacion
12. Tendencias con correlaciones y peso
13. Perfil completo con alergias
14. Bloqueo con Face ID

### Para quien sirve
- Validar el FLUJO y la UX con usuarios/amigos (sin esperar al build)
- Mostrar a inversores/mentores el concepto y el diseno
- Demo en reuniones sin depender de Xcode

---

## 2. DEMO REAL EN EL SIMULADOR (requiere tu Mac)

### Prerrequisitos
- [ ] Mac con Xcode 26
- [ ] XcodeGen instalado: brew install xcodegen
- [ ] Cuenta de desarrollador (para dispositivo fisico; NO para simulador)

### Pasos (15-30 min la primera vez)
cd <ruta-del-proyecto>
xcodegen generate
open Neximed.xcodeproj
Cmd+B  (compilar)
Cmd+R  (ejecutar en simulador)

### Que funcionara en el SIMULADOR vs dispositivo real
| Funcionalidad | Simulador | iPhone real |
|---------------|-----------|-------------|
| UI y navegacion | OK | OK |
| Onboarding, perfil, botiquin, recordatorios | OK | OK |
| Correlaciones, recomendaciones, exportacion | OK | OK |
| Dictado por voz | Depende del Mac | OK |
| HealthKit (constantes reales) | Datos de ejemplo | OK |
| IA on-device (Apple Intelligence) | NO | OK (iPhone 15 Pro+) |
| Face ID | Simulable en menu | OK |

### Para una demo pulida en el simulador
1. En el simulador: Features > Face ID > Enrolled (para probar el bloqueo)
2. HealthKit no tiene datos reales - la demo mostrara valores 0. Opcion: en
   Ajustes del simulador, Health app, anadir datos de ejemplo manualmente.
3. Si quieres datos de ejemplo automaticos, dime y anado un 'Modo Demo' que
   rellena datos ficticios al arrancar (solo en DEBUG).

---

## 3. CUANDO ESTARA LISTA LA DEMO REAL

| Paso | Estado | Tiempo |
|------|--------|--------|
| Codigo completo (39 archivos Swift) | Listo | - |
| Demo HTML interactiva | Lista (DEMO.html) | - |
| Generar proyecto Xcode | En tu Mac | 2 min |
| Compilar y resolver errores del compilador real | Pendiente | 1-3 h |
| Prueba en simulador | Pendiente | 30 min |
| Prueba en iPhone fisico | Pendiente | 30 min |
| TestFlight (para compartir con otros) | Pendiente | 1-2 h |

Resumen: la demo HTML puedes mostrarla HOY. La demo real en simulador
esta a ~2-4 horas de trabajo en tu Mac (compilar + resolver errores). La demo
en iPhone fisico y TestFlight requiere cuenta de desarrollador.
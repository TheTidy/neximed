# Neximed - Checklist de Publicacion en App Store (actualizado)

> Estado real verificado. Documento de control para llevar la app hasta la App Store.

---

## FASE 0 - Requisitos previos

- [ ] Cuenta de desarrollador Apple (99 USD/ano) - TU ACCION
- [x] Mac con Xcode 26 - lo tienes
- [x] XcodeGen (brew install xcodegen)
- [x] Bundle ID com.neximed.app - en project.yml y Info.plist
- [ ] iPhone fisico para pruebas - TU ACCION

---

## FASE A - Build Verde (requiere tu Mac)

- [ ] xcodegen generate
- [ ] open Neximed.xcodeproj + seleccionar Team
- [ ] Compilar Cmd+B y resolver errores
- [ ] Probar en dispositivo real: Dashboard, dictado, OCR, camara, PDF
- [ ] Probar en iPhone sin Apple Intelligence (Modo Basico)

---

## FASE B - Material App Store

- [x] Icono 1024x1024 - AppIcon.png listo en Assets.xcassets
- [x] Banner feature 16:9 - feature-banner.jpeg listo
- [x] Fondo de screenshots - screenshot-backdrop.jpeg listo
- [ ] Capturar screenshots reales 6.7 pulgadas (5 pantallas) - requiere build
- [x] Politica de privacidad publica - https://thetidy.github.io/neximed/privacy-policy/

---

## FASE C - TestFlight

- [ ] Subir build (Archive > Distribute > TestFlight) - ver TESTFLIGHT-GUIDE.md
- [ ] Anadir testers internos
- [ ] Probar instalacion en 2-3 dispositivos
- [ ] Verificar que no hay actividad de red

---

## FASE D - App Store Connect y Revision

- [ ] Crear app con datos de APPLE-SUBMISSION.md (seccion 1)
- [ ] Pegar descripcion (seccion 2)
- [ ] Pegar notas de revision (seccion 3)
- [ ] Responder cuestionario de salud (seccion 4)
- [ ] Subir icono y screenshots
- [ ] Enviar a revision (24-72h)

---

## Documentos de apoyo

- APPLE-SUBMISSION.md - TODO el texto listo para pegar
- TESTFLIGHT-GUIDE.md - pasos exactos en tu Mac
- Politica de privacidad: https://thetidy.github.io/neximed/privacy-policy/
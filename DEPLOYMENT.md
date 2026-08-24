# 🌐 Neximed — Despliegue en GitHub Pages

## URLs del sitio (EN LÍNEA ✅)

| Página | URL |
|--------|-----|
| Demo interactiva (inicio) | https://thetidy.github.io/neximed/ |
| Política de privacidad | https://thetidy.github.io/neximed/privacy-policy/ |
| Repositorio | https://github.com/TheTidy/neximed |

## Qué se ha desplegado

- **index.html** — la demo interactiva (14 pantallas navegables con las imágenes reales)
- **privacy-policy/index.html** — la política de privacidad (obligatoria para HealthKit en App Store)
- **Neximed/Resources/Images/** — las imágenes que usa la demo
- **.nojekyll** — desactiva Jekyll (sitio HTML puro, se sirve directo)
- **README.md** — descripción del repo

## Notas técnicas

- El push vía git falló por el sandbox de red (schannel sin credenciales), así que se subió
  todo con la API de GitHub (gh api) — equivalente y seguro.
- El primer build de Pages falló (Jekyll); se resolvió añadiendo .nojekyll.
- Para actualizar en el futuro: edita los archivos locales y vuelve a subirlos con gh api,
  o una vez tengas credenciales git configuradas usa git push.

## En App Store Connect

- URL de política de privacidad que debes pegar: https://thetidy.github.io/neximed/privacy-policy/
- Este enlace se pide al configurar la ficha de la app (obligatorio con HealthKit).
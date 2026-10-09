# Ranking global: configuración

## 1. Base de datos (Supabase, gratis)
1. Entra a supabase.com, crea cuenta y **New project** (elige nombre, contraseña de base de datos y región; espera a que termine).
2. Menú **SQL Editor → New query**, pega todo `supabase.sql` y pulsa **Run**. Debe decir "Success".
3. Menú **Project Settings → API** (o **API Keys**): copia la **Project URL** y la clave **anon** (o **publishable**).
4. En `english-exam-kahoot.html` busca `RELLENA` y completa: `const SB_URL="https://TU-PROYECTO.supabase.co"` y `SB_KEY="tu clave anon/publishable"`.

## 2. Publicar en GitHub Pages
1. En github.com: **New repository** (público), por ejemplo `english-kahoot`.
2. **Add file → Upload files**: sube el HTML ya configurado **renombrado a `index.html`** y haz **Commit**.
3. **Settings → Pages → Build and deployment**: Source = *Deploy from a branch*, Branch = `main` y carpeta `/ (root)` → **Save**.
4. En 1 o 2 minutos aparece la URL: `https://TU-USUARIO.github.io/english-kahoot/`.

## 3. Qué es público y qué es secreto
- **Público (puede ir en el HTML):** `SB_URL` y la clave `anon`/`publishable`. Sin políticas de acceso, esa clave no puede tocar las tablas; solo puede llamar a las 4 funciones del SQL.
- **Secreto (NUNCA en el HTML ni en GitHub):** la clave `service_role`/`secret` y la contraseña de la base de datos.

## 4. Limitaciones reales (no es a prueba de trampas)
- GitHub Pages no tiene servidor: el navegador calcula la puntuación. La base de datos solo acepta resultados **plausibles** (25 preguntas, puntos entre 600 y 1000 por acierto, nombre válido, una partida cada 40 s por jugador, sin reenvíos). Alguien técnico podría enviar un resultado falso dentro de esos rangos, o generar identificadores nuevos para saltarse el límite de frecuencia.
- Para verificar de verdad habría que mandar las respuestas y recalcular en una Supabase Edge Function. Esta versión no lo hace.
- **Identidad:** cada navegador crea un identificador anónimo guardado en el dispositivo. Un mismo nombre en dos dispositivos cuenta como dos jugadores, y borrar los datos del navegador crea un jugador nuevo. Agrupar por nombre sería peor: cualquiera podría usar el apodo de otro. Para identidad entre dispositivos se necesitan cuentas (Supabase Auth).
- Si el ranking no está disponible, el juego sigue funcionando para practicar y avisa que no se guardó.

## 5. Pruebas con dos dispositivos
1. Con `SB_URL`/`SB_KEY` vacíos: el juego funciona y avisa "Ranking no configurado".
2. Dispositivo A: nombre "Ana", juega las 25 preguntas → "Resultado guardado · Tu puesto: #1".
3. Dispositivo B (otra red o navegador): nombre "Luis", juega → aparece su puesto; abre **🏆 Ver ranking** en ambos y comprueba que ven a Ana y a Luis en el mismo orden.
4. En A juega otra vez como "Ana": en *Mejores jugadores* sigue 1 sola fila de Ana (su mejor puntuación); en *Historial* hay 2 partidas. Prueba el orden por fecha y por puntos.
5. Espera al menos 40 s entre partidas del mismo dispositivo; antes de eso el guardado falla a propósito y ofrece **Reintentar**.
6. Apaga el wifi al terminar una partida: debe decir que NO se publicó; al volver la conexión, **Reintentar guardado** lo publica.
7. Nombres como `<b>hola</b>` o "A" (1 letra) deben rechazarse; un nombre con espacios extra se limpia.
8. Pulsa varias veces "Ver resultados": solo debe haber una partida en el historial.
9. Si hay más de 20 jugadores, **Ver más** carga el siguiente bloque.

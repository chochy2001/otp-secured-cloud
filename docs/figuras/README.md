# Figuras renderizadas

Esta carpeta contiene las versiones gráficas (PNG o SVG) de los diagramas que aparecen como bloques `mermaid` en `docs/arquitectura.md`. Las imágenes binarias NO se versionan en el repositorio público para no inflar el historial de git con archivos no de texto. Cada miembro del equipo regenera las imágenes localmente cuando arma el PDF del entregable.

## Cómo regenerar todas las figuras

1. Instalar [mermaid-cli](https://github.com/mermaid-js/mermaid-cli):

   ```bash
   npm install -g @mermaid-js/mermaid-cli
   ```

2. Desde la raíz del repo, ejecutar el script auxiliar (a crear si se decide automatizar):

   ```bash
   ./scripts/build-figures.sh
   ```

   Si el script no existe aún, regenerar manualmente cada figura siguiendo las instrucciones de la sección final de `docs/arquitectura.md`.

3. Verificar que `docs/figuras/figura1.png`, `figura3.png` y `figura4.png` existen antes de ejecutar `./scripts/build-pdf.sh`.

## Listado de figuras

Coordinado con `docs/indice-figuras.md`:

| Archivo | Origen en `docs/arquitectura.md` | Descripción |
|---|---|---|
| `figura1.png` | Bloque mermaid "Figura 1: Arquitectura del sistema" | Componentes y conexiones HTTPS/LDAPS |
| `figura3.png` | Bloque mermaid "Figura 3: Flujo de autenticación 2FA" | Diagrama de secuencia LDAP + OTP |
| `figura4.png` | Bloque mermaid "Figura 4: Red Docker y puertos" | Mapa de la red Docker `otpsec` |

Las figuras 2 (árbol LDAP) y 5 (cifrado de archivos) se mantienen como ASCII en sus archivos correspondientes (`docs/arbol-ldap.md` y `docs/memoria-tecnica.md`); pueden migrarse a mermaid si el equipo decide unificar el formato visual del PDF.

## Por qué no se versionan los binarios

1. Git maneja mal los binarios: cada cambio mínimo (nuevo color, nueva fuente) sobrescribe el blob entero, infla el repo y dificulta los diffs.
2. La fuente de verdad es el código mermaid en `docs/arquitectura.md`. Si las imágenes y el código se desincronizan, prevalece el código.
3. La regeneración local toma menos de 10 segundos y solo se hace cuando se ensambla el PDF final.

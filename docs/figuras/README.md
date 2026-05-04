# Figuras renderizadas

Esta carpeta contiene las versiones gráficas (PNG) de los seis diagramas que aparecen como bloques `mermaid` en `docs/arquitectura.md`, `docs/arbol-ldap.md` y `docs/memoria-tecnica.md`. Las imágenes binarias NO se versionan en el repositorio público para no inflar el historial de git con archivos no de texto. Cada miembro del equipo regenera las imágenes localmente cuando arma el PDF del entregable.

## Cómo regenerar las figuras

```bash
npm install -g @mermaid-js/mermaid-cli
./scripts/build-figures.sh
```

El script:

1. Lee los tres archivos fuente (`docs/arquitectura.md`, `docs/arbol-ldap.md`, `docs/memoria-tecnica.md`).
2. Localiza cada encabezado `### Figura N:` y extrae el bloque `mermaid` que sigue.
3. Exporta cada bloque a `docs/figuras/figuraN.png` con `mmdc` (mermaid-cli).

Verificar que `docs/figuras/figura1.png` a `figura6.png` existen antes de ejecutar `./scripts/build-pdf.sh`. Si faltan, el PDF se genera de todas formas pero los bloques `mermaid` aparecen como código fuente en lugar de las imágenes.

## Listado de figuras

Coordinado con `docs/indice-figuras.md`:

| Archivo | Origen | Descripción |
|---|---|---|
| `figura1.png` | `docs/arquitectura.md`, `### Figura 1: Arquitectura del sistema` | Componentes y conexiones HTTPS y LDAPS |
| `figura2.png` | `docs/arbol-ldap.md`, `### Figura 2: Árbol LDAP del proyecto` | Base DN, OUs, usuarios y cuenta de servicio |
| `figura3.png` | `docs/arquitectura.md`, `### Figura 3: Flujo de autenticación 2FA` | Diagrama de secuencia LDAP + OTP |
| `figura4.png` | `docs/arquitectura.md`, `### Figura 4: Red Docker y puertos` | Mapa de la red Docker `otpsec` |
| `figura5.png` | `docs/memoria-tecnica.md`, `### Figura 5: Flujo de cifrado del lado servidor` | Subida, almacenamiento cifrado y descarga descifrada |
| `figura6.png` | `docs/memoria-tecnica.md`, `### Figura 6: Flujo de carpetas compartidas` | Emisor, OCS Sharing API y destinatario |

## Por qué no se versionan los binarios

1. Git maneja mal los binarios: cada cambio mínimo (nuevo color, nueva fuente) sobrescribe el blob entero, infla el repo y dificulta los diffs.
2. La fuente de verdad es el código mermaid en los tres archivos `docs/*.md` mencionados arriba. Si las imágenes y el código se desincronizan, prevalece el código.
3. La regeneración local toma menos de 10 segundos y solo se hace cuando se ensambla el PDF final.

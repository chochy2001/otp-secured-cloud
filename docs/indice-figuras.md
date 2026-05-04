# Índice de figuras

Las seis figuras del entregable viven como bloques `mermaid` dentro de los archivos del repositorio. GitHub las renderiza en línea cuando se ve la página web del proyecto y `scripts/build-figures.sh` las exporta a PNG con `mermaid-cli` para incluirlas en el PDF final.

| Número | Figura | Archivo fuente | Encabezado en el archivo |
|---|---|---|---|
| 1 | Arquitectura del sistema: componentes, conexiones HTTPS y LDAPS | `docs/arquitectura.md` | `### Figura 1: Arquitectura del sistema` |
| 2 | Árbol LDAP del proyecto: base DN, OUs, usuarios y cuenta de servicio | `docs/arbol-ldap.md` | `### Figura 2: Árbol LDAP del proyecto` |
| 3 | Flujo de autenticación 2FA: cliente web, OwnCloud, OpenLDAP y privacyIDEA | `docs/arquitectura.md` | `### Figura 3: Flujo de autenticación 2FA` |
| 4 | Red Docker y puertos publicados | `docs/arquitectura.md` | `### Figura 4: Red Docker y puertos` |
| 5 | Flujo de cifrado del lado servidor: subida, almacenamiento y descarga | `docs/memoria-tecnica.md` | `### Figura 5: Flujo de cifrado del lado servidor` |
| 6 | Flujo de carpetas compartidas: emisor, OCS Sharing API y destinatario | `docs/memoria-tecnica.md` | `### Figura 6: Flujo de carpetas compartidas` |

## Cómo regenerar las figuras

```bash
npm install -g @mermaid-js/mermaid-cli
./scripts/build-figures.sh
```

El script lee los tres archivos fuente, busca cada encabezado `### Figura N:` y exporta el bloque `mermaid` que sigue a `docs/figuras/figuraN.png`. Los binarios viven en esa carpeta solo en máquinas locales: el `.gitignore` los excluye porque la fuente de verdad es el código `mermaid` en los archivos `.md`.

## Cómo citar una figura desde el cuerpo del PDF

Después de ejecutar `build-figures.sh`, las imágenes se referencian con sintaxis Pandoc estándar:

```markdown
![Figura 1: Arquitectura del sistema](docs/figuras/figura1.png)
```

`scripts/build-pdf.sh` espera que las figuras existan en `docs/figuras/` antes de ejecutarse; si faltan, el PDF se genera de todas formas pero las figuras aparecen con el bloque `mermaid` en bruto en lugar de la imagen.

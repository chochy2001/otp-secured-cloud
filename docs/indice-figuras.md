# Índice de figuras

| Número | Figura | Ubicación |
|---|---|---|
| 1 | Diagrama de arquitectura del sistema | `docs/arquitectura.md`, sección "Diagrama" |
| 2 | Árbol LDAP del proyecto: base DN, OUs, usuarios y cuenta de servicio | `docs/arbol-ldap.md`, sección "Árbol final" |
| 3 | Flujo de autenticación 2FA: cliente web, OwnCloud, LDAP, privacyIDEA | `docs/arquitectura.md`, sección "Flujo de petición" |
| 4 | Diagrama de red Docker entre servicios | `docs/arquitectura.md`, sección "Red" |
| 5 | Flujo de cifrado del lado servidor: subida, almacenamiento, descarga | `docs/memoria-tecnica.md`, sección "Fase 6" |
| 6 | Flujo de carpetas compartidas: emisor, OCS API, destinatario | `docs/memoria-tecnica.md`, sección "Carpetas compartidas" |

## Notas para los autores del entregable

Estas figuras viven hoy como diagramas ASCII en los archivos referenciados. Antes de imprimir el PDF, hay dos opciones:

1. **Mantener el ASCII** y aclarar que las figuras se construyen con caracteres visibles para que sean legibles en cualquier visor sin depender de fuentes ni renderizado externo.
2. **Renderizar versión gráfica** con una herramienta libre (por ejemplo, draw.io exportando a PDF/PNG, o Mermaid embebido en un Markdown procesado por Pandoc). Si se elige esta opción, los archivos exportados deben vivir en `docs/figuras/` con el nombre `figura-N.png` o `.svg`. Esa carpeta no existe aún en el repositorio para no agregar binarios al historial; se crea cuando el equipo decida formato y herramienta.

El equipo aún tiene que decidir cuál opción seguir. En cualquier caso, esta tabla queda lista para citarse desde el cuerpo del documento como "(figura N)".

# Índice

1. Portada
*Prefacio*
2. Introducción
3. Conceptos básicos de 2FA mediante tokens OTP
4. Diseño del árbol LDAP del proyecto
5. Arquitectura del sistema
6. Memoria técnica paso a paso
   - 6.1 Estructura del repositorio
   - 6.2 Levantamiento del stack
   - 6.3 Identificación: OpenLDAP
   - 6.4 Autenticación primer factor: contraseña LDAP
   - 6.5 Autenticación segundo factor: privacyIDEA y app TOTP
   - 6.6 OwnCloud y orquestación 2FA
   - 6.7 Carpetas compartidas y cifrado del lado destinatario
   - 6.8 Auditoría (complemento académico, no evaluable)
   - 6.9 Reproducibilidad
7. Conclusiones
   - 7.1 Conclusión por equipo
   - 7.2 Conclusiones individuales
8. Glosario de términos
9. Bibliografía
10. Índice de figuras

## Mapeo de secciones a archivos del repositorio

| Sección | Archivo en `docs/` |
|---|---|
| 1. Portada | `portada.md` |
| 2. Introducción | `introduccion.md` |
| 3. Conceptos básicos | `conceptos-basicos.md` |
| 4. Diseño del árbol LDAP | `arbol-ldap.md` |
| 5. Arquitectura | `arquitectura.md` |
| 6. Memoria técnica paso a paso | `memoria-tecnica.md` |
| 7. Conclusiones | `conclusiones.md` |
| 8. Glosario | `glosario.md` |
| 9. Bibliografía | `bibliografia.md` |
| 10. Índice de figuras | `indice-figuras.md` |

`docs/auditoria.md` queda fuera del entregable porque el profesor confirmó que la cuarta capa no se evalúa. Permanece en el repositorio como evidencia complementaria del marco conceptual.

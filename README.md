# otp-secured-cloud

Servicio de almacenamiento de información con doble factor de autenticación (2FA) vía OTP, construido con **OpenLDAP**, **PrivacyIDEA**, **FreeOTP** y **OwnCloud**.

Proyecto final de la materia **Seguridad Informática Avanzada** (SIA), Facultad de Ingeniería, UNAM, semestre 2026-2.

## Aviso importante de seguridad e implementación

Este repositorio es material **académico** para el curso SIA de la FI-UNAM. Se construyó con fines **didácticos** y prioriza la claridad pedagógica sobre la robustez que se exigiría a un sistema productivo.

Antes de reutilizar este código para cualquier cosa que no sea estudiar, considera estos puntos:

1. **El archivo `.env` con contraseñas se versiona a propósito.** Es una mala práctica reconocida: lo hacemos para que los integrantes del equipo y quien revise el proyecto puedan levantar el entorno sin intercambiar secretos por otro canal. En producción las credenciales deben estar fuera del repositorio (gestor de secretos, variables en CI, etc.).
2. **Las contraseñas por defecto son débiles y compartidas.** Todos los usuarios comparten una misma contraseña (`sia-user-2026`). En producción debería existir política de contraseñas, rotación, y contraseñas únicas por usuario.
3. **Las contraseñas académicas siguen versionadas en `.env`.** Los LDIFs ya siembran `userPassword` como hashes `{SSHA}` generados con `slappasswd`, pero el archivo `.env` conserva los valores en claro para reproducibilidad del laboratorio. En producción esos secretos no deben versionarse.
4. **Los certificados TLS son autofirmados** con una CA del propio proyecto. Esto es válido para un laboratorio cerrado pero inservible en internet público: cualquier cliente verá advertencias de certificado si no confía explícitamente en la CA local.
5. **No hay backup, alta disponibilidad, ni hardening del sistema operativo.** Un solo contenedor por servicio, volúmenes locales, sin replicación.
6. **No hay rate limiting, lockout de cuentas, ni protección contra fuerza bruta** más allá de lo que trae cada componente por defecto.
7. **El cifrado de archivos de OwnCloud en modo *master key* cifra en disco pero no protege contra el administrador del servidor.** La llave maestra vive en el mismo servidor. Para protección frente a operadores sería necesario cifrado extremo a extremo en el cliente.
8. **No se aplica segmentación de red entre servicios.** Todos comparten la misma red Docker sin políticas de firewall internas.

**Si llegaste aquí desde Google y planeas usar esto en serio**, trata este repo como un punto de partida para aprender los conceptos y luego lee los docs oficiales de cada componente para entender cómo endurecerlo antes de exponerlo.

---

## Stack y mapeo al control de acceso

| Capa de control de acceso | Componente | Función | Evaluable |
|---|---|---|---|
| Identificación | OpenLDAP 2.x | Directorio único de usuarios con UIDs | Sí |
| Autenticación (algo que *conozco*) | OpenLDAP | Valida usuario + contraseña | Sí |
| Autenticación (algo que *tengo*) | PrivacyIDEA + FreeOTP | Valida el token OTP generado en el móvil | Sí |
| Autorización | OwnCloud | Permisos de lectura/escritura por carpeta y por usuario, sin sincronizar grupos LDAP | Sí |
| Auditoría | Logs de OpenLDAP, PrivacyIDEA, OwnCloud | Registro de eventos de acceso | No (complemento académico, el profesor confirmó que no se evalúa) |

## Estado del proyecto

El estado detallado y la trazabilidad por fases viven en [`docs/estado-proyecto.md`](docs/estado-proyecto.md). Resumen actual:

- [x] Estructura del repositorio y documentación base
- [x] OpenLDAP con dos unidades organizacionales (Desarrollo, Seguridad) y usuarios sembrados
- [x] PrivacyIDEA integrado con el LDAP como *resolver*
- [x] Token TOTP enrolado y validado contra la API (`scripts/privacyidea-enroll-test-token.sh`)
- [x] CA local del proyecto, LDAPS en 6636 y HTTPS de PrivacyIDEA en 8443
- [x] OwnCloud 10.15 levantado con MariaDB, Redis y Caddy (TLS en 9443)
- [x] OwnCloud integrado con backend LDAP por LDAPS y plugin `twofactor_privacyidea`
- [x] Cifrado de archivos compartidos activado (Server Side Encryption, master key)
- [x] Carpetas compartidas con OCS Sharing API y descifrado por el destinatario (`scripts/owncloud-share-verify.sh`)
- [x] Auditoría reproducible de los 8 eventos clave (`scripts/audit-capture.sh`, complemento académico no evaluable)
- [x] Memoria técnica, conclusiones, glosario, bibliografía y guion de exposición redactados
- [x] Arranque completo con un solo comando (`scripts/bootstrap.sh`)

## Arranque rápido

```bash
git clone git@github.com:chochy2001/otp-secured-cloud.git
cd otp-secured-cloud
./scripts/bootstrap.sh
```

`bootstrap.sh` genera la CA local, levanta Docker Compose con build, espera los healthchecks, configura privacyIDEA y OwnCloud, y corre la batería evaluable: LDAP, PrivacyIDEA, OwnCloud, login LDAP + OTP, cifrado local y archivo compartido descifrado por el destinatario. Si termina con `Listo`, el stack está operativo.

Para regenerar también las bitácoras de auditoría no evaluables:

```bash
./scripts/bootstrap.sh --with-audit
```

Para una guía exhaustiva del día de la presentación (pre-flight, demo en vivo y plan B), ver [`docs/como-probar.md`](docs/como-probar.md).

## Estructura del repositorio

```
otp-secured-cloud/
|-- compose/              docker-compose.yml con todos los servicios
|-- ldap/
|   `-- bootstrap/        LDIFs que siembran el directorio al primer arranque
|-- privacyidea/          Configuración del servicio de OTP
|-- owncloud/             Hooks y documentación del servicio OwnCloud
|-- certs/                Certificados TLS autofirmados del proyecto (con README)
|-- scripts/              Utilidades (pruebas, regenerar certs, etc.)
`-- docs/                 Memoria técnica, diagramas, conceptos básicos
```

## Documentación

Operación y bitácoras:

- [Estado del proyecto](docs/estado-proyecto.md): documento vivo con avance y trazabilidad por fases
- [Guía paso a paso para el equipo](docs/guia-equipo.md): cómo clonar y probar el proyecto en tu máquina
- [Cómo probar el proyecto antes y durante la presentación](docs/como-probar.md): pre-flight, demo en vivo y plan B
- [Cierre de sesión de trabajo](docs/cierre-sesion.md): puertos, credenciales y comandos para retomar
- [Auditoría: muestreo de eventos](docs/auditoria.md): bitácoras reales de los 8 eventos clave (generadas por `scripts/audit-capture.sh`)
- [Preguntas abiertas al profesor](docs/preguntas-abiertas.md)

Material para el entregable (40 por ciento de la nota):

- [Portada](docs/portada.md)
- [Introducción](docs/introduccion.md)
- [Conceptos básicos de 2FA y OTP](docs/conceptos-basicos.md)
- [Diseño del árbol LDAP](docs/arbol-ldap.md)
- [Arquitectura del sistema](docs/arquitectura.md)
- [Memoria técnica paso a paso](docs/memoria-tecnica.md)
- [Conclusiones](docs/conclusiones.md)
- [Glosario de términos](docs/glosario.md)
- [Bibliografía](docs/bibliografia.md)
- [Índice de figuras](docs/indice-figuras.md)
- [Índice del entregable](docs/indice.md)

Ensamblado del PDF, HTML y DOCX: `./scripts/build-pdf.sh`. Requiere `pandoc` siempre y un motor LaTeX si se quiere PDF (recomendado: `tectonic`, instalable en macOS sin sudo con `brew install tectonic`; en Linux `sudo apt install texlive-xetex`).

Material para la exposición (30 por ciento de la nota):

- [Guion de exposición de 30 min](docs/guion-exposicion.md): bloques por integrante y plan B
- [Slides en formato Marp](docs/presentacion.md): cada `---` separa una diapositiva, listo para abrir con Marp o reveal.js
- [Manual para enrolar TOTP en FreeOTP físico](docs/manual-freeotp.md)

## Integrantes

Equipo del proyecto final de Seguridad Informática Avanzada, semestre 2026-2:

| Integrante | Correo |
|---|---|
| Arellanes Conde Esteban | esteban.arellanes@ingenieria.unam.edu |
| Ferreira Rojas Mauricio | mauferreira183@gmail.com |
| López Segundo Luis Iván | lopezsknd@gmail.com |
| Olvera González Arely | arely.olvera@ingenieria.unam.edu |
| Rufino López María Elena | mariaelena.rufino424@gmail.com |
| Salgado Miranda Jorge | ohchochy@gmail.com |

## Licencia

Proyecto académico. Código liberado con fines educativos.

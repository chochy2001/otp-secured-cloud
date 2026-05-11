# Estado del proyecto

Documento vivo. Se actualiza en cada commit que cambie el avance.

**Última actualización:** 2026-05-11 (cierre técnico validado)
**Fecha de entrega:** 2026-05-29 (viernes)
**Duración de la exposición:** 30 minutos, todos los integrantes participan.

## 1. Resumen ejecutivo

| Componente | Estado | Evidencia |
|---|---|---|
| Repositorio en GitHub | Operativo | `chochy2001/otp-secured-cloud`, rama `main` sincronizada con `origin/main` |
| OpenLDAP | Funcional | `scripts/ldap-verify.sh` pasa con `Todo OK` |
| PrivacyIDEA | Funcional | Servicio en Docker, admin inicial, resolver LDAP y realm verificados con `scripts/privacyidea-verify.sh` |
| Certificados TLS (CA propia) | Funcional | `./scripts/generate-certs.sh` produce CA + certs; LDAPS en 6636, HTTPS de privacyIDEA en 8443 y resolver LDAP interno por LDAPS |
| OwnCloud | Funcional | Versión 10.15 con backend LDAP por LDAPS, plugin `twofactor_privacyidea` activo y Server Side Encryption con master key. `owncloud-verify.sh` pasa los 6 checks. |
| Cifrado de archivos | Funcional | Server Side Encryption activo; `owncloud-login-verify.sh` sube un archivo y confirma que queda cifrado en el volumen |
| Carpetas compartidas | Funcional | `scripts/owncloud-share-verify.sh` automatiza emisor, share por OCS API y descarga descifrada por el destinatario |
| Auditoría reproducible | Funcional, complemento académico no evaluable | `scripts/audit-capture.sh` dispara 8 eventos clave y produce `docs/auditoria.md` con extractos reales de logs |
| Documentación del entregable | Redactada y completa | Portada con el profesor (César Sanabria Pineda), introducción, memoria técnica, conclusiones (de equipo y los 6 individuales), glosario, bibliografía e índices viven en `docs/`. Cada integrante puede afinar el suyo si quiere |
| Diagramas para el PDF | Renderizados | 6 figuras en `mermaid` distribuidas en `docs/arquitectura.md`, `docs/arbol-ldap.md` y `docs/memoria-tecnica.md`. `scripts/build-figures.sh` las exporta a PNG con `mermaid-cli` y se embeben en el PDF |
| Ensamblado del entregable | Funcional | `scripts/build-pdf.sh` produce PDF (con tectonic), HTML y DOCX en `build/`. PDF de 28 páginas con las 6 figuras embebidas, primera página con la portada del proyecto, validado |
| Presentación de 30 min | Guion redactado | `docs/guion-exposicion.md` reparte tiempos por integrante, plan B con respaldo y logística |
| Arranque completo desde clone | Funcional | `scripts/bootstrap.sh` genera certs, levanta Compose, configura servicios y ejecuta pruebas end-to-end |
| Cierre de sesión | Documentado | [`cierre-sesion.md`](cierre-sesion.md) resume estado, comando único de arranque, puertos y credenciales |

Los estados son descriptivos y se actualizan conforme avanza cada bloque.

## 2. Entregables del profesor y su estado

Según el PDF oficial del proyecto, el entregable consta de tres bloques:

### 2.1 Documentación del proyecto (40% de la evaluación)

| Sección requerida | Estado | Archivo |
|---|---|---|
| Portada | Redactada con el profesor (César Sanabria Pineda) | [`portada.md`](portada.md) |
| Introducción | Redactada | [`introduccion.md`](introduccion.md) |
| Índice | Redactado | [`indice.md`](indice.md) |
| Índice de figuras con referencia | Redactado | [`indice-figuras.md`](indice-figuras.md) |
| Conceptos básicos de 2FA mediante tokens OTP | Redactado | [`conceptos-basicos.md`](conceptos-basicos.md) |
| Diagrama detallado de la solución | 6 figuras en mermaid renderizadas a PNG y embebidas en el PDF | [`arquitectura.md`](arquitectura.md), [`arbol-ldap.md`](arbol-ldap.md), [`memoria-tecnica.md`](memoria-tecnica.md) |
| Memoria técnica paso a paso | Redactada de extremo a extremo | [`memoria-tecnica.md`](memoria-tecnica.md) |
| Auditoría con extractos reales de logs | Generada y versionada (complemento académico no evaluable, el profesor confirmó que esta capa queda fuera del alcance evaluado) | [`auditoria.md`](auditoria.md) |
| Conclusión por equipo | Redactada | [`conclusiones.md`](conclusiones.md) |
| Conclusiones individuales (6) | Redactadas y proporcionadas (Salgado 304 palabras, los demás cerca de 200) | [`conclusiones.md`](conclusiones.md) |
| Bibliografía | Redactada | [`bibliografia.md`](bibliografia.md) |
| Glosario de términos | Redactado | [`glosario.md`](glosario.md) |
| Ensamblado del PDF, HTML y DOCX final | Funcional y validado: el último build produjo PDF de 28 páginas con las 6 figuras embebidas | [`scripts/build-pdf.sh`](../scripts/build-pdf.sh) |

### 2.2 Exposición del proyecto (30% de la evaluación)

| Tarea | Estado |
|---|---|
| Definir orden de intervenciones y tiempos por integrante | Redactado en [`guion-exposicion.md`](guion-exposicion.md) |
| Guion de la demo en vivo | Redactado en [`guion-exposicion.md`](guion-exposicion.md), bloque 5 |
| Manual para enrolar el TOTP demo en FreeOTP físico | Redactado | [`manual-freeotp.md`](manual-freeotp.md) |
| Ensayo operativo | Guion y checklist listos | [`guion-exposicion.md`](guion-exposicion.md), [`como-probar.md`](como-probar.md) |
| Respaldo del entorno | Reproducible por diseño | `scripts/bootstrap.sh` reconstruye y valida el stack desde clone |
| Grabación de respaldo | Flujo documentado | [`como-probar.md`](como-probar.md), bloque de demo en vivo |

### 2.3 Funcionamiento (30% de la evaluación, 5 componentes x 6%)

| Validación | Estado | Notas |
|---|---|---|
| i. Alta de usuarios en LDAP | Hecho | 6 usuarios + 1 cuenta de servicio, verificado |
| ii. Integración con PrivacyIDEA | Hecho | Resolver LDAP `sia-ldap` y realm `sia` configurados |
| iii. Emisión de token OTP desde FreeOTP | Hecho | `scripts/privacyidea-enroll-test-token.sh` enrola con `genkey=1`, calcula TOTP local y valida vía API; flujo con FreeOTP documentado para la demo |
| iv. Implementación de OwnCloud | Hecho | OwnCloud 10.15 con Caddy TLS, MariaDB, Redis, LDAP y encryption activos |
| v. Integración 2FA LDAP + OTP | Hecho | `owncloud-login-verify.sh` valida login web con LDAP + OTP contra PrivacyIDEA |

## 3. Plan por fases

### Fase 1: Estructura del repositorio
- [x] README con aviso académico de seguridad
- [x] `.gitignore`, `.env`, `.env.example`
- [x] Estructura de carpetas (`compose/`, `ldap/`, `privacyidea/`, `owncloud/`, `certs/`, `scripts/`, `docs/`)

### Fase 2: Directorio LDAP
- [x] `osixia/openldap:1.5.0` en Docker Compose
- [x] Base DN `dc=sia,dc=unam,dc=mx`
- [x] OU Desarrollo + 3 usuarios
- [x] OU Seguridad + 3 usuarios
- [x] OU Servicios + cuenta `svc-owncloud` de solo lectura, separada del filtro de usuarios humanos
- [x] ACL de lectura para la cuenta de servicio, sin exponer `userPassword`
- [x] Script `scripts/ldap-verify.sh` que valida admin, conteo de usuarios, lectura de servicio y rechazo de credenciales inválidas
- [x] Documentación del diseño del árbol (`docs/arbol-ldap.md`)
- [x] Guía para el equipo (`docs/guia-equipo.md`)

### Fase 3: PrivacyIDEA
- [x] Servicio en `docker-compose.yml`
- [x] Imagen propia reproducible con `PRIVACYIDEA_VERSION=3.10.2`
- [x] Bootstrap idempotente de llaves, base SQLite y admin inicial
- [x] Configuración del resolver LDAP y realm por API con `scripts/privacyidea-configure.sh`
- [x] Validación de servicio, admin, resolver, conteo de 6 usuarios y realm con `scripts/privacyidea-verify.sh`
- [x] Documentar el how-to en `privacyidea/README.md` (requisitos, arranque, verificación, configuración automatizada y alternativa por UI)
- [x] Script `scripts/privacyidea-validate-otp.sh` que valida un OTP contra `POST /validate/check`, el mismo endpoint que usará OwnCloud
- [x] Documentar el flujo de enrolamiento del token TOTP desde la UI y el escaneo del QR con FreeOTP
- [x] Script `scripts/privacyidea-enroll-test-token.sh` que enrola con `genkey=1`, imprime la URL `otpauth://` y calcula+valida el TOTP localmente con Python stdlib, sin depender de un teléfono
- [x] Manual para enrolar un token en un móvil real con FreeOTP usando la URL que imprime el script

### Fase 4: Certificados TLS (CA propia)
- [x] `scripts/generate-certs.sh` genera CA local + certs de servidor para `openldap`, `privacyidea` y `owncloud` (idempotente, con `--force` para regenerar)
- [x] Compose monta los certs en OpenLDAP, publica `6636:636` para LDAPS y mantiene `389` durante la transición
- [x] PrivacyIDEA arranca en HTTPS sobre `8443` con `pi-manage run --cert --key`; el healthcheck exige HTTPS y valida la CA local
- [x] Resolver LDAP de PrivacyIDEA usa `ldaps://openldap:636` y valida la CA local montada en el contenedor
- [x] Helper `scripts/lib-curl.sh` define `--cacert certs/ca.crt` para que los scripts confíen en la CA local
- [x] `scripts/ldap-verify.sh` extendido con un paso 8 que valida la cadena de certificación de LDAPS
- [x] Documentar generación, confianza de la CA y precauciones de laboratorio (`certs/README.md`)

### Fase 5: OwnCloud y 2FA (cerrada)
El profesor confirmó por correo las cuatro preguntas abiertas (ver [`preguntas-abiertas.md`](preguntas-abiertas.md)): cliente web suficiente, versión a elección del equipo (OwnCloud 10.15 Server), LDAP autentica y OwnCloud autoriza, auditoría como complemento no evaluable.

- [x] Decisión: OwnCloud 10.15 Server con `twofactor_privacyidea`, demo solo web
- [x] Servicios MariaDB 10.11, Redis 7 y OwnCloud 10.15 en `docker-compose.yml`
- [x] Caddy 2 como TLS terminator delante de OwnCloud, publicando 9443
- [x] Cert `owncloud.crt` agregado a `scripts/generate-certs.sh` con SANs apropiados
- [x] Árbol LDAP con `ou=Usuarios` y `ou=Grupos`, alineado con `ldapBaseUsers` y `ldapBaseGroups` de `user_ldap`
- [x] `scripts/owncloud-configure.sh` automatiza user_ldap (LDAPS), `twofactor_privacyidea` y cifrado master key
- [x] `scripts/owncloud-verify.sh` valida HTTPS, instalación, configuración LDAP, 6 usuarios, app 2FA y cifrado activo
- [x] Hook `owncloud/10-trust-project-ca.sh` registra la CA local en el trust store del contenedor antes del arranque
- [x] `scripts/owncloud-login-verify.sh` valida login web LDAP + OTP, subida WebDAV y archivo cifrado en disco
- [x] `scripts/owncloud-share-verify.sh` automatiza el flujo emisor + destinatario con OCS Sharing API y valida lectura cifrada por el destinatario

### Fase 6: Cifrado de archivos compartidos (cerrada)
- [x] Activar módulo *Server Side Encryption* con `OC_DEFAULT_MODULE`
- [x] Demostrar archivos cifrados en disco con `scripts/owncloud-login-verify.sh`
- [x] Validar que el destinatario puede abrirlos al compartir (`scripts/owncloud-share-verify.sh`)

### Fase 7: Auditoría y bitácoras (cerrada)

- [x] Habilitar niveles de log adecuados en OpenLDAP, PrivacyIDEA, OwnCloud (loglevel ajustado en runtime, OwnCloud retorna a 1 al final del script)
- [x] Capturar ejemplos reales de los 8 eventos clave con `scripts/audit-capture.sh` que escribe `docs/auditoria.md`

### Fase 8: Documentación final y entrega (cerrada)
- [x] Portada en [`portada.md`](portada.md) con el profesor César Sanabria Pineda
- [x] Introducción en [`introduccion.md`](introduccion.md)
- [x] Conclusión de equipo en [`conclusiones.md`](conclusiones.md)
- [x] Conclusiones individuales (primer borrador equilibrado, cada integrante puede afinarlo)
- [x] Glosario en [`glosario.md`](glosario.md) con 30+ términos
- [x] Bibliografía en [`bibliografia.md`](bibliografia.md) con RFCs y docs oficiales
- [x] Índice de figuras en [`indice-figuras.md`](indice-figuras.md), 6 figuras en mermaid
- [x] Memoria técnica consolidada en [`memoria-tecnica.md`](memoria-tecnica.md)
- [x] PNG de las 6 figuras renderizadas con `./scripts/build-figures.sh` (mermaid-cli + tectonic instalados)
- [x] PDF, HTML y DOCX ensamblados con `./scripts/build-pdf.sh` en `build/`

### Fase 9: Presentación (guion, checklist y respaldo reproducible)
- [x] Guion de 30 min con división por integrante en [`guion-exposicion.md`](guion-exposicion.md)
- [x] Manual del enrolamiento físico en FreeOTP en [`manual-freeotp.md`](manual-freeotp.md)
- [x] Checklist operativo de la demo en [`como-probar.md`](como-probar.md)
- [x] Reconstrucción reproducible desde clone con `scripts/bootstrap.sh`
- [x] Flujo completo documentado para grabación o repetición en vivo

## 4. Decisiones de alcance

### 4.1 Preguntas al profesor (las cuatro contestadas)

El detalle textual de cada respuesta vive en [`preguntas-abiertas.md`](preguntas-abiertas.md). Resumen:

| Pregunta | Respuesta del profesor | Implicación |
|---|---|---|
| 1. Alcance del cliente | Cliente web es suficiente | Demo solo por navegador, sin app passwords |
| 2. Versión de OwnCloud | La que gusten, debe funcionar | OwnCloud 10.15 Server (PHP) confirmado |
| 3. Modelo de autorización | LDAP autentica, OwnCloud autoriza | Permisos por carpeta en OwnCloud, sin sincronía de grupos |
| 4. Auditoría | No se revisará en la evaluación | Se mantiene como contexto académico, no como entregable |

Sobre los supuestos, el profesor pidió "documéntelos y que se tenga claridad de ellos". La tabla consolidada de los siete supuestos con su archivo de referencia está en `preguntas-abiertas.md`.

### 4.2 Repositorio y reproducibilidad

La fuente de verdad técnica es el repositorio `chochy2001/otp-secured-cloud`. La operación evaluable no depende de cuentas personales: con acceso de lectura al repo, Docker y los prerrequisitos de `docs/como-probar.md`, se puede reconstruir el entorno completo ejecutando `./scripts/bootstrap.sh`.

## 5. Historial reciente de avance

### 2026-04-24
- Repositorio creado en GitHub con commits modulares limpios.
- OpenLDAP verificado de punta a punta con `scripts/ldap-verify.sh`.
- Contraseñas consolidadas al patrón `sia-<rol>-2026`.
- Guía paso a paso para el equipo publicada en `docs/guia-equipo.md`.
- Invitaciones a los 5 colaboradores enviadas; Arely aceptada.
- PDF de preguntas preparado y compartido con el profesor fuera del repo.
- Revisión de estilo y consistencia de toda la documentación (sin emojis, sin caracteres decorativos, ASCII básico en los diagramas).
- Cuenta de servicio `svc-owncloud` reclasificada a `simpleSecurityObject` y `organizationalRole` para que no aparezca en búsquedas de usuarios humanos con filtro `(objectClass=inetOrgPerson)`.
- `scripts/ldap-verify.sh` endurecido: ahora valida conteos exactos (3 en Desarrollo, 3 en Seguridad, 6 humanos en total) y rechazo de contraseña inválida.
- Agregados `README.md` iniciales en `certs/`, `owncloud/` y `privacyidea/` para documentar el rol de cada carpeta antes de completar su contenido final.
- PrivacyIDEA agregado al `docker-compose.yml` con imagen propia, configuración reproducible y resolver LDAP funcional.

### 2026-04-25
- Script `scripts/privacyidea-enroll-test-token.sh` que enrola un TOTP con `genkey=1`, imprime la URL `otpauth://` para FreeOTP y valida el código localmente con Python stdlib contra `POST /validate/check`. Cierra técnicamente la validación iii (emisión de OTP) sin depender de un teléfono.
- Script `scripts/privacyidea-validate-otp.sh` para probar OTPs reales contra la API; mismo endpoint que usará OwnCloud en la Fase 5.
- Fase 4 (TLS) completa: CA local del proyecto + certs de servidor con SANs adecuadas, LDAPS publicado en 6636, HTTPS de privacyIDEA publicado en 8443, resolver LDAP interno usando LDAPS y scripts adaptados para confiar en la CA con `--cacert`.

### 2026-04-27
- En este punto el profesor todavía no había contestado las cuatro preguntas tácticas. Se avanza con los supuestos declarados para no detener el desarrollo. (Las cuatro respuestas llegaron días después y están registradas en `preguntas-abiertas.md` y en la sección 4.1 de este documento.)
- Fase 5 cerrada técnicamente: OwnCloud 10.15 Server levantado con MariaDB 10.11, Redis 7 y Caddy 2 como terminador TLS sobre el puerto 9443.
- Cert `owncloud.crt` añadido a `scripts/generate-certs.sh` con SANs `owncloud`, `owncloud-server`, `owncloud-proxy`, `localhost`, `127.0.0.1`, `::1`.
- `scripts/owncloud-configure.sh` automatiza `user_ldap`, `twofactor_privacyidea` y cifrado local.
- `scripts/owncloud-verify.sh` valida HTTPS, `occ status`, LDAPS, 6 usuarios, plugin 2FA y encryption.
- `scripts/owncloud-login-verify.sh` valida login web con LDAP + OTP, subida WebDAV y cifrado del archivo en disco.
- Se agrega `docs/cierre-sesion.md` con estado para retomar, puertos, credenciales de laboratorio, comandos de verificación, limpieza Docker y próximos pasos.

### 2026-05-04
- `scripts/owncloud-share-verify.sh` cierra carpetas compartidas: enrola TOTP para emisor y destinatario, sube archivo, crea share por OCS Sharing API con cookies y descarga descifrada por el destinatario.
- `scripts/audit-capture.sh` produce `docs/auditoria.md` con extractos reales de logs de los 8 eventos clave; sube `loglevel` de OwnCloud a debug durante la captura y lo restaura al terminar.
- Documentación del entregable redactada: portada, introducción, memoria técnica, conclusión de equipo, glosario, bibliografía, índice y índice de figuras.
- 6 figuras del entregable migradas a `mermaid` en `docs/arquitectura.md`, `docs/arbol-ldap.md` y `docs/memoria-tecnica.md`. `scripts/build-figures.sh` las exporta a PNG con `mermaid-cli`.
- `scripts/build-pdf.sh` ensambla el PDF final con `pandoc` y un motor LaTeX.
- Guion de exposición de 30 min repartido por integrante con plan B y manual para enrolar el TOTP demo en un teléfono real con FreeOTP.

## 6. Estado de cierre técnico

Todo lo automatizable está cerrado y validado: controles i a v, carpetas compartidas, cifrado en disco, auditoría como complemento, documentación redactada, profesor en portada, conclusiones, figuras renderizadas y PDF/HTML/DOCX ensamblados en `build/`.

La verificación final para cualquier laptop de demo es:

```bash
git pull origin main
./scripts/bootstrap.sh
```

Si el comando termina con `Listo`, el entorno cumple el flujo funcional exigido por el proyecto: alta LDAP, integración con PrivacyIDEA, emisión/validación OTP, OwnCloud operativo, 2FA LDAP + OTP, autorización por carpetas compartidas y cifrado de archivos.

# Cierre de sesión de trabajo

**Fecha:** 2026-05-11

Este documento resume el estado exacto para retomar el proyecto sin depender de memoria de sesiones anteriores.

## Estado actual

La base técnica, el arranque automatizado, las pruebas end-to-end y el material del entregable están completos. Desde un clone limpio, el laboratorio se levanta y valida con un solo comando: `./scripts/bootstrap.sh`.

| Bloque | Estado | Verificación |
|---|---|---|
| OpenLDAP | Listo | `./scripts/ldap-verify.sh` (8 checks) |
| PrivacyIDEA | Listo | `./scripts/privacyidea-configure.sh` y `./scripts/privacyidea-verify.sh` (6 checks) |
| TOTP reproducible | Listo | `./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo2` para pruebas automáticas |
| TOTP físico de demo | Listo | `usuario.desarrollo1` enrolado en Proton Authenticator; no rotar ese usuario antes de presentar |
| TLS local con CA propia | Listo | `./scripts/generate-certs.sh` y verificaciones incluidas |
| OwnCloud | Listo | `./scripts/owncloud-configure.sh` y `./scripts/owncloud-verify.sh` (6 checks) |
| Login LDAP + OTP end-to-end | Listo | `./scripts/owncloud-login-verify.sh usuario.desarrollo2` |
| Cifrado del archivo en disco | Listo | Verificado por `owncloud-login-verify.sh` con cabecera `HBEGIN` |
| Carpetas compartidas y descifrado en destinatario | Listo | `./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1` |
| Auditoría reproducible (complemento académico, el profesor confirmó que no se evalúa) | Listo | `./scripts/audit-capture.sh` produce `docs/auditoria.md` |
| Documentación del entregable (40% nota) | Redactada | Portada, introducción, memoria técnica, glosario, bibliografía, conclusiones, índices |
| Documento final operativo | Redactado | `docs/documento-final.md` resume arquitectura, pruebas, demo y defensa |
| Guion de exposición de 30 min | Redactado | `docs/guion-exposicion.md` con división por integrante |
| Slides en formato Marp | Redactados | `docs/presentacion.md`, 30 diapositivas separadas por `---` |
| Manual para enrolar TOTP físico | Redactado | `docs/manual-freeotp.md` cubre FreeOTP y Proton Authenticator |
| Guía operativa de la demo | Redactada | `docs/como-probar.md` con pre-flight, demo y plan B |
| Arranque completo desde clone | Listo | `./scripts/bootstrap.sh` genera certs, levanta Compose, configura servicios y corre pruebas |

## Servicios del proyecto

| Servicio | URL o puerto | Uso |
|---|---|---|
| OpenLDAP plano | `localhost:389` | Se mantiene por compatibilidad durante la transición |
| OpenLDAP LDAPS | `localhost:6636` | Canal recomendado para clientes LDAP |
| PrivacyIDEA | `https://localhost:8443` | Administración y API de OTP |
| OwnCloud | `https://localhost:9443` | Portal principal de la demo |

Puertos internos no publicados:

| Servicio | Puerto interno | Nota |
|---|---|---|
| OwnCloud server | `8080` | Solo accesible desde Caddy dentro de Docker |
| MariaDB OwnCloud | `3306` | Solo red Docker |
| Redis OwnCloud | `6379` | Solo red Docker |

## Credenciales de laboratorio

| Cuenta | Usuario | Contraseña |
|---|---|---|
| LDAP admin | `cn=admin,dc=sia,dc=unam,dc=mx` | `sia-admin-2026` |
| LDAP servicio | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` | `sia-svc-2026` |
| Usuario LDAP demo | `usuario.desarrollo1` | `sia-user-2026` |
| PrivacyIDEA admin | `admin` | `sia-pi-admin-2026` |
| OwnCloud admin | `admin` | `sia-oc-admin-2026` |

Estas credenciales son de laboratorio y están versionadas a propósito para reproducibilidad académica. La sección "Aviso de seguridad" del README explica por qué esa decisión sería inaceptable en un entorno real.

## Cómo retomar el laboratorio

Desde la raíz del repositorio:

Cadena principal evaluable:

```bash
git pull origin main
./scripts/bootstrap.sh
```

El script cierra identificación, autenticación 2FA, autorización, cifrado y carpetas compartidas. Si termina con `Listo`, el entorno está listo.

Si el teléfono ya tiene enrolado el token real de `usuario.desarrollo1`, no correr pruebas automáticas pasando ese usuario explícitamente. Para validar sin romper el token físico:

```bash
./scripts/ldap-verify.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo2
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

Complemento académico opcional (auditoría, no se evalúa):

```bash
./scripts/bootstrap.sh --with-audit
```

Se corre si se quiere regenerar `docs/auditoria.md` con extractos frescos de los logs.

## Cómo generar los artefactos de entrega

Solo necesario una vez, antes de imprimir el PDF:

```bash
# Renderizar las 6 figuras Mermaid a PNG
npm install -g @mermaid-js/mermaid-cli
./scripts/build-figures.sh

# Ensamblar el PDF del entregable
brew install pandoc tectonic          # macOS (tectonic no requiere sudo)
# o: sudo apt install pandoc texlive-xetex   # Linux
./scripts/build-pdf.sh

# El PDF aparece en build/entregable-otp-secured-cloud.pdf
```

Las figuras y el PDF NO se versionan: la fuente de verdad es el Markdown y el código Mermaid.

## Cómo apagar el proyecto

Para liberar puertos sin borrar datos:

```bash
docker compose -f compose/docker-compose.yml --env-file .env down
```

Para reiniciar desde cero y volver a importar los LDIF:

```bash
docker compose -f compose/docker-compose.yml --env-file .env down -v
./scripts/bootstrap.sh
```

## Limpieza de Docker

Comandos seguros usados al cierre:

```bash
docker builder prune -a -f
docker system df
```

No borrar volúmenes de Docker de otros proyectos sin revisar primero `docker volume ls` y `docker volume inspect`.

## Reglas de estilo del repositorio

Antes de cerrar cualquier avance hay que correr:

```bash
shellcheck scripts/*.sh privacyidea/entrypoint.sh owncloud/10-trust-project-ca.sh
docker compose -f compose/docker-compose.yml --env-file .env config >/tmp/otp-compose-config.yml
git diff --check
rg -n --hidden -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]|[\x{2190}-\x{21FF}]|[\x{2500}-\x{257F}]|[\x{2013}\x{2014}]' -g '!certs/**' -g '!.git/**' -g '!build/**' .
```

El último comando debe regresar sin resultados.

## Pasos finales del equipo antes de la entrega

1. Abrir `build/entregable-otp-secured-cloud.pdf` y revisar visualmente portada, índice, bibliografía, glosario y tablas antes de imprimir.
2. Si se edita algún `.md`, regenerar figuras (`./scripts/build-figures.sh`) y PDF (`./scripts/build-pdf.sh`).
3. Enrolar o confirmar el TOTP demo en un teléfono real con Proton Authenticator o FreeOTP siguiendo `docs/manual-freeotp.md`.
4. Ejecutar las validaciones seguras con `usuario.desarrollo2`, `usuario.desarrollo3` y `usuario.seguridad1` para no rotar el token físico de `usuario.desarrollo1`.
5. Usar `docs/guion-exposicion.md` y `docs/presentacion.md` para el ensayo operativo del equipo.

## Nota sobre historia de Git

Los archivos actuales y los mensajes de commit están limpios de referencias ajenas al proyecto y de caracteres prohibidos por las convenciones del repo. Las verificaciones automáticas (`shellcheck`, `git diff --check` y búsqueda de Unicode prohibido) corren en cada cierre de sesión.

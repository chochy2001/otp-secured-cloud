# Cierre de sesión de trabajo

**Fecha:** 2026-05-04

Este documento resume el estado exacto para retomar el proyecto sin depender de memoria de sesiones anteriores.

## Estado actual

La base técnica y el material del entregable están completos. Lo que queda depende del equipo (ensayo, snapshot, conclusiones individuales si se quieren afinar).

| Bloque | Estado | Verificación |
|---|---|---|
| OpenLDAP | Listo | `./scripts/ldap-verify.sh` (8 checks) |
| PrivacyIDEA | Listo | `./scripts/privacyidea-configure.sh` y `./scripts/privacyidea-verify.sh` (6 checks) |
| TOTP reproducible | Listo | `./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo1` |
| TLS local con CA propia | Listo | `./scripts/generate-certs.sh` y verificaciones incluidas |
| OwnCloud | Listo | `./scripts/owncloud-configure.sh` y `./scripts/owncloud-verify.sh` (6 checks) |
| Login LDAP + OTP end-to-end | Listo | `./scripts/owncloud-login-verify.sh usuario.desarrollo1` |
| Cifrado del archivo en disco | Listo | Verificado por `owncloud-login-verify.sh` con cabecera `HBEGIN` |
| Carpetas compartidas y descifrado en destinatario | Listo | `./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1` |
| Auditoría reproducible (complemento académico, el profesor confirmó que no se evalúa) | Listo | `./scripts/audit-capture.sh` produce `docs/auditoria.md` |
| Documentación del entregable (40% nota) | Redactada | Portada, introducción, memoria técnica, glosario, bibliografía, conclusiones, índices |
| Guion de exposición de 30 min | Redactado | `docs/guion-exposicion.md` con división por integrante |
| Slides en formato Marp | Redactados | `docs/presentacion.md`, 30 diapositivas separadas por `---` |
| Manual para enrolar FreeOTP físico | Redactado | `docs/manual-freeotp.md` |
| Guía operativa de la demo | Redactada | `docs/como-probar.md` con pre-flight, demo y plan B |

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

```bash
git pull origin main
./scripts/generate-certs.sh
docker compose -f compose/docker-compose.yml --env-file .env up -d --build
./scripts/ldap-verify.sh
./scripts/privacyidea-configure.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-configure.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo1
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
./scripts/audit-capture.sh
```

Si los nueve scripts terminan con `Todo OK`, `OK: ... descifró y leyó` o `Auditoría escrita en ...`, el entorno está listo. Tiempo total estimado: cinco a siete minutos en una laptop moderna.

## Cómo generar los artefactos de entrega

Solo necesario una vez, antes de imprimir el PDF:

```bash
# Renderizar las 6 figuras Mermaid a PNG
npm install -g @mermaid-js/mermaid-cli
./scripts/build-figures.sh

# Ensamblar el PDF del entregable
brew install pandoc basictex          # macOS
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
./scripts/generate-certs.sh
docker compose -f compose/docker-compose.yml --env-file .env up -d --build
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

1. Cada integrante revisa su párrafo en `docs/conclusiones.md` y lo afina si quiere ajustar tono o agregar anécdotas personales.
2. El equipo confirma el nombre del profesor y lo escribe en `docs/portada.md` (línea con la línea de relleno).
3. Generar las figuras (`./scripts/build-figures.sh`) y el PDF (`./scripts/build-pdf.sh`).
4. Enrolar el TOTP demo en un teléfono real con FreeOTP siguiendo `docs/manual-freeotp.md`.
5. Ensayo grabado de la presentación al menos 48 horas antes (con `docs/guion-exposicion.md` y los slides `docs/presentacion.md`).
6. Snapshot del entorno o grabación de la demo como respaldo.
7. La noche anterior, correr la batería completa de `docs/como-probar.md` para confirmar que la laptop sigue verde.

## Nota sobre historia de Git

Los archivos actuales y los mensajes de commit están limpios de referencias a herramientas de asistencia y de caracteres prohibidos por las convenciones del repo. Las verificaciones automáticas (`shellcheck`, `git diff --check`, búsqueda de Unicode prohibido y de referencias a IA) corren en cada cierre de sesión.

# Cierre de sesión de trabajo

**Fecha:** 2026-04-27

Este documento resume el estado exacto para retomar el proyecto sin depender de memoria de la sesión anterior.

## Estado actual

La base técnica del proyecto queda funcional:

| Bloque | Estado | Verificación |
|---|---|---|
| OpenLDAP | Listo | `./scripts/ldap-verify.sh` |
| PrivacyIDEA | Listo | `./scripts/privacyidea-configure.sh` y `./scripts/privacyidea-verify.sh` |
| TOTP reproducible | Listo | `./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo1` |
| TLS local | Listo | `./scripts/generate-certs.sh` y verificaciones incluidas |
| OwnCloud | Listo | `./scripts/owncloud-configure.sh` y `./scripts/owncloud-verify.sh` |
| Login LDAP + OTP | Listo | `./scripts/owncloud-login-verify.sh usuario.desarrollo1` |
| Cifrado en disco | Listo | Verificado por `owncloud-login-verify.sh` al subir un archivo real |

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

Estas credenciales son de laboratorio y están versionadas a propósito para reproducibilidad académica.

## Cómo retomar

Desde la raíz del repo:

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
```

Si todos los scripts pasan, el entorno quedó listo para continuar con documentación, auditoría y demo.

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

## Reglas de estilo del repo

Antes de cerrar cualquier avance:

```bash
shellcheck scripts/*.sh privacyidea/entrypoint.sh owncloud/10-trust-project-ca.sh
docker compose -f compose/docker-compose.yml --env-file .env config >/tmp/otp-compose-config.yml
git diff --check
rg -n --hidden -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]|[\x{2190}-\x{21FF}]|[\x{2500}-\x{257F}]|[\x{2013}\x{2014}]' -g '!certs/**' -g '!.git/**' .
```

El último comando debe regresar sin resultados. Además, antes de publicar, hacer una búsqueda de términos ajenos al proyecto acordados por el equipo sin escribir esa lista dentro del repositorio.

## Pendientes siguientes

1. Preparar carpetas compartidas y permisos de demo en OwnCloud.
2. Documentar auditoría: login exitoso, login fallido, OTP rechazado, token enrolado y acceso a archivo.
3. Consolidar memoria técnica final con portada, introducción, índice, glosario, bibliografía y conclusiones.
4. Preparar guion de exposición de 30 minutos y repartir intervenciones.
5. Hacer snapshot o grabación de respaldo antes de la presentación.

## Nota sobre historia de Git

Los archivos actuales y los mensajes de commit actuales están limpios de referencias a herramientas de asistencia. Si alguien revisa diffs históricos con búsquedas profundas, puede encontrar textos antiguos que fueron eliminados después. Corregir eso requiere reescritura de historia y force push, por lo que debe decidirse con el equipo antes de hacerlo.

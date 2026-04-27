# Guía para el equipo: cómo levantar el proyecto

Esta guía describe el procedimiento paso a paso para clonar el repositorio, levantar el entorno y verificar que todo funciona en tu máquina. Está pensada para que cualquiera del equipo (y cualquier evaluador del curso) pueda reproducir el entorno sin depender de otra persona.

## 1. Requisitos previos

Antes de empezar necesitas tener instalado:

| Herramienta | Versión recomendada | Para qué |
|---|---|---|
| Docker Desktop (Mac/Windows) o Docker Engine (Linux) | 24.0 o superior | Correr los contenedores |
| Docker Compose | v2.x (viene con Docker Desktop) | Orquestar varios servicios |
| Git | 2.30 o superior | Clonar el repositorio |
| Bash | 4.x o superior | Correr el script de verificación (`scripts/ldap-verify.sh`) |

En macOS, `bash` viene en versión 3.2 por compatibilidad histórica, pero el script de verificación funciona también con esa versión. Si tienes una más nueva instalada vía Homebrew, mejor.

Verifica que Docker esté corriendo:

```bash
docker info
```

Si da error de socket, abre Docker Desktop y espera a que termine de iniciar antes de seguir.

## 2. Clonar el repositorio

```bash
git clone https://github.com/chochy2001/otp-secured-cloud.git
cd otp-secured-cloud
```

## 3. Revisar las contraseñas del entorno

El archivo `.env` viene incluido a propósito con las credenciales académicas del proyecto. Úsalas tal cual para desarrollo. **No repliques esta práctica en un proyecto real.**

Las credenciales siguen el patrón `sia-<rol>-2026`:

| Uso | Valor |
|---|---|
| Admin del LDAP (`cn=admin,dc=sia,dc=unam,dc=mx`) | `sia-admin-2026` |
| Admin de la configuración LDAP (`cn=admin,cn=config`) | `sia-config-2026` |
| Cuenta de servicio (`cn=svc-owncloud,ou=Servicios`) | `sia-svc-2026` |
| Cualquiera de los 6 usuarios de prueba | `sia-user-2026` |

## 4. Levantar OpenLDAP

Desde la raíz del repositorio:

```bash
cd compose
docker compose --env-file ../.env up -d openldap
cd ..
```

El primer arranque tarda un par de minutos porque descarga la imagen `osixia/openldap:1.5.0` (~200 MB). Los siguientes son inmediatos.

Para ver los logs del contenedor mientras arranca:

```bash
docker logs -f otpsec-openldap
```

Ctrl-C para salir del `tail` (el contenedor sigue corriendo).

## 5. Verificar que el directorio está operativo

Corre el script de verificación:

```bash
./scripts/ldap-verify.sh
```

Deberías ver:

1. Una consulta con `dn: dc=sia,dc=unam,dc=mx`.
2. Los 3 usuarios de `ou=Desarrollo` con su `uid`, `cn` y `mail`.
3. Los 3 usuarios de `ou=Seguridad`.
4. `dn:cn=svc-owncloud,ou=Servicios,...` que confirma que la cuenta de servicio puede hacer bind.
5. La línea final `Todo OK`.

Si alguno de los pasos falla, revisa la sección [Problemas comunes](#7-problemas-comunes) más abajo.

## 6. Pruebas manuales útiles

### Validar el primer factor desde la terminal (login de usuario)

Simular lo que hará OwnCloud al autenticar al usuario:

```bash
docker exec -it otpsec-openldap ldapwhoami -x \
  -H ldap://localhost \
  -D "uid=usuario.desarrollo1,ou=Desarrollo,dc=sia,dc=unam,dc=mx" \
  -w "sia-user-2026"
```

Debe responder con `dn:uid=usuario.desarrollo1,...`.

### Probar que una contraseña incorrecta se rechaza

```bash
docker exec -it otpsec-openldap ldapwhoami -x \
  -H ldap://localhost \
  -D "uid=usuario.desarrollo1,ou=Desarrollo,dc=sia,dc=unam,dc=mx" \
  -w "contrasena-incorrecta"
```

Debe responder `ldap_bind: Invalid credentials (49)`. Ese error es importante para la capa de **auditoría**: aparecerá también en los logs del contenedor.

### Consultar manualmente todo el árbol

```bash
docker exec -it otpsec-openldap ldapsearch -x \
  -H ldap://localhost \
  -b "dc=sia,dc=unam,dc=mx" \
  -D "cn=admin,dc=sia,dc=unam,dc=mx" \
  -w "sia-admin-2026"
```

## 7. Problemas comunes

### El puerto 389 o 636 ya está en uso

macOS y algunos Linux traen servicios de directorio corriendo nativos (`opendirectoryd`, `slapd`) que pueden ocupar esos puertos. Solución rápida: cambiar el puerto publicado en `compose/docker-compose.yml`, por ejemplo `"1389:389"`. Luego todas las pruebas con `-H ldap://localhost` deben apuntar a `-H ldap://localhost:1389`.

### Cambié un LDIF y mi cambio no aparece en el directorio

Osixia solo ejecuta los LDIFs de `ldap/bootstrap/` **una vez**, en el primer arranque sobre volúmenes vacíos. Si ya había corrido el contenedor antes, los LDIFs posteriores se ignoran. Para forzar la reimportación:

```bash
cd compose
docker compose down -v    # la -v borra volúmenes y datos del LDAP
docker compose --env-file ../.env up -d openldap
```

Atención: esto borra todos los datos actuales del LDAP. En desarrollo no importa; en producción sería catastrófico.

### `docker info` da error de socket

Docker Desktop no está corriendo. Ábrelo desde Aplicaciones (macOS) o con `systemctl --user start docker-desktop` (Linux), espera unos segundos y reintenta.

### El script `ldap-verify.sh` se queja de variables indefinidas

Asegúrate de que el archivo `.env` está en la raíz del repo. El script lo carga con `source $ROOT_DIR/.env`. Si acabas de clonar no debería ser necesario crearlo: viene incluido en el repo.

### Cambié `.env` pero los contenedores siguen con las contraseñas viejas

Docker Compose pasa las variables al momento de crear el contenedor. Si cambias `.env` después, tienes que recrear:

```bash
cd compose
docker compose down
docker compose --env-file ../.env up -d openldap
```

Y si además cambiaste contraseñas usadas en los LDIFs, necesitas además `down -v` para que el LDAP las recargue desde cero.

## 8. Apagar el entorno

```bash
cd compose
docker compose down          # apaga los contenedores pero mantiene los datos
# ó:
docker compose down -v       # apaga y borra los volúmenes (datos del LDAP)
```

## 9. Qué sigue

El entorno actual ya levanta OpenLDAP, PrivacyIDEA y la CA local del proyecto. Mientras OwnCloud sigue bloqueado por las respuestas pendientes del profesor, el equipo debe mantener esta guía alineada con los scripts de verificación y preparar la documentación final del entregable.

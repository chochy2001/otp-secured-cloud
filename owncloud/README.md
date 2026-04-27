# OwnCloud

Servicio de almacenamiento de archivos del proyecto. Aquí es donde el usuario final teclea su nombre de usuario y contraseña (primer factor, validados contra OpenLDAP) y luego un código TOTP (segundo factor, validado contra PrivacyIDEA), antes de poder ver, subir y compartir archivos.

## Versión y arquitectura

Se usa **OwnCloud 10.15 Server** (imagen `owncloud/server:10.15`), que es la rama estable con el plugin oficial `twofactor_privacyidea` maduro y probado. Componentes del despliegue:

| Servicio | Imagen | Rol |
|---|---|---|
| `owncloud-db` | `mariadb:10.11` | Base de datos relacional de OwnCloud |
| `owncloud-redis` | `redis:7-alpine` | Cache y bloqueo de archivos |
| `owncloud-server` | `owncloud/server:10.15` | PHP-FPM + nginx interno; sirve la app en HTTP plano dentro de la red Docker |
| `owncloud-proxy` | `caddy:2-alpine` | Termina TLS hacia el host con el cert firmado por la CA local; reenvía a `owncloud-server:8080` |

## Variables de entorno

Vienen del archivo `.env` en la raíz del repositorio:

| Variable | Para qué |
|---|---|
| `OC_ADMIN_USERNAME` | Nombre del admin inicial de OwnCloud |
| `OC_ADMIN_PASSWORD` | Contraseña del admin inicial |
| `OC_DB_ROOT_PASSWORD` | Contraseña de root de MariaDB |
| `OC_DB_PASSWORD` | Contraseña del usuario `owncloud` en MariaDB |
| `OC_URL` | URL pública del servicio (HTTPS) |

## Arranque

Desde la raíz del repositorio:

```bash
# 1. Si aún no existen, generar la CA local y los certs (incluye owncloud.crt)
./scripts/generate-certs.sh

# 2. Levantar los cuatro servicios
cd compose
docker compose --env-file ../.env up -d owncloud-db owncloud-redis
# Esperar 10-20 segundos a que MariaDB termine su bootstrap antes de subir el resto
docker compose --env-file ../.env up -d owncloud-server owncloud-proxy
cd ..

# 3. Verificar
./scripts/owncloud-verify.sh
```

La interfaz queda disponible en `https://localhost:9443`. La primera vez tarda alrededor de un minuto porque OwnCloud corre las migraciones iniciales de la base.

## Verificación

```bash
./scripts/owncloud-verify.sh
```

El script valida:

1. Caddy presenta un cert TLS firmado por la CA local (`certs/ca.crt`).
2. `GET /status.php` devuelve `installed: true` y la versión esperada.
3. `occ status` responde dentro del contenedor.
4. El admin inicial existe en la base de usuarios local de OwnCloud.

Cuando se agreguen las fases siguientes (backend LDAP, 2FA, cifrado), este script se irá extendiendo con pasos adicionales.

## Pendiente para fases siguientes

- Configurar el backend LDAP de OwnCloud (`user_ldap`) apuntando a `ldaps://openldap:636` con la CA local validada.
- Instalar y configurar el plugin `twofactor_privacyidea` para que pida un OTP de PrivacyIDEA después del bind LDAP.
- Activar Server Side Encryption en modo *master key* (AES-256) para los archivos compartidos.
- Crear permisos de prueba sobre carpetas para los seis usuarios del LDAP.

# OwnCloud

Servicio de almacenamiento del proyecto. Se usa OwnCloud Server 10.15 con MariaDB, Redis y Caddy como terminador TLS.

## Decisiones asumidas

El profesor no respondió las preguntas abiertas, así que se avanza con estos supuestos:

1. OwnCloud Server 10 clásico, no OwnCloud Infinite Scale.
2. La demo principal es por navegador web.
3. LDAP es fuente de identidad y primer factor.
4. PrivacyIDEA es el segundo factor vía el plugin `twofactor_privacyidea`.
5. Los permisos de carpetas se gestionan en OwnCloud. Los grupos LDAP quedan preparados bajo `ou=Grupos`, pero no son obligatorios para la demo actual.

## Servicios

| Servicio | Imagen | Rol |
|---|---|---|
| `owncloud-db` | `mariadb:10.11` | Base de datos de OwnCloud |
| `owncloud-redis` | `redis:7-alpine` | Cache y locking |
| `owncloud-server` | `owncloud/server:10.15` | Aplicación OwnCloud |
| `owncloud-proxy` | `caddy:2-alpine` | HTTPS público en `https://localhost:9443` |

OwnCloud habla con OpenLDAP por `ldaps://openldap:636` y con PrivacyIDEA por `https://privacyidea:8443/` dentro de la red Docker `otpsec`.

## Archivos de esta carpeta

| Archivo | Qué hace |
|---|---|
| `10-trust-project-ca.sh` | Hook de arranque de la imagen oficial. Registra la CA local del proyecto en el trust store del contenedor para validar LDAPS y HTTPS internos. |
| `README.md` | Esta guía. |

## Configuración automatizada

Desde la raíz del repo:

```bash
./scripts/owncloud-configure.sh
```

El script hace lo siguiente:

1. Levanta OpenLDAP, PrivacyIDEA, MariaDB, Redis, OwnCloud y Caddy.
2. Habilita `user_ldap`.
3. Crea o actualiza la configuración LDAP `s01`.
4. Apunta OwnCloud a `ldaps://openldap:636`.
5. Usa la cuenta `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx`.
6. Activa `twofactor_privacyidea`.
7. Configura el plugin con URL interna `https://privacyidea:8443/`, realm `sia` y verificación SSL activa.
8. Habilita Server Side Encryption con `OC_DEFAULT_MODULE`.
9. Sincroniza los usuarios LDAP.

## Verificación

```bash
./scripts/owncloud-verify.sh
```

Valida:

1. `https://localhost:9443/status.php`.
2. `occ status`.
3. Configuración LDAP por LDAPS con validación de certificado activa.
4. Resolución exacta de los 6 usuarios LDAP.
5. App `twofactor_privacyidea` activa y apuntando a PrivacyIDEA por HTTPS interno.
6. Cifrado del lado servidor activo.

Para probar el flujo completo con sesión web real:

```bash
./scripts/owncloud-login-verify.sh usuario.desarrollo1
```

Ese script crea un token TOTP de prueba, inicia sesión en OwnCloud con contraseña LDAP, envía el OTP al plugin de PrivacyIDEA, sube un archivo por WebDAV usando la sesión autenticada y comprueba que el archivo no queda en texto plano dentro del volumen.

## Acceso web

URL:

```text
https://localhost:9443
```

Credenciales útiles:

| Usuario | Contraseña | Uso |
|---|---|---|
| `admin` | `sia-oc-admin-2026` | Admin local de OwnCloud |
| `usuario.desarrollo1` | `sia-user-2026` | Usuario LDAP de demo |
| `usuario.seguridad1` | `sia-user-2026` | Usuario LDAP de demo |

Cuando `twofactor_privacyidea` está activo, los usuarios LDAP requieren OTP para completar el login web.

## Nota sobre certificados

El navegador mostrará advertencia si la CA local `certs/ca.crt` no está importada como autoridad confiable. Los scripts no dependen del trust store del sistema porque llaman a `curl` con `--cacert certs/ca.crt`.

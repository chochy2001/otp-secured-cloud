# PrivacyIDEA

Servicio de emisión y validación de tokens OTP. Actúa como segundo factor en el flujo 2FA: una vez que OpenLDAP valida usuario y contraseña, PrivacyIDEA valida el código generado por FreeOTP en el móvil.

## Archivos

| Archivo | Qué hace |
|---|---|
| `Dockerfile` | Imagen basada en `python:3.11-slim-bookworm`, con `PRIVACYIDEA_VERSION` fijado vía argumento de build. Las dependencias de Python se instalan desde el `requirements.txt` oficial de esa versión en GitHub, para un build determinista. |
| `pi.cfg` | Configuración mínima: SQLite en `/data`, llaves de cifrado y auditoría bajo `/data`, logging a `/var/log/privacyidea/`. Los secretos se leen de variables de entorno. |
| `entrypoint.sh` | Bootstrap idempotente: en el primer arranque genera llave de cifrado, llaves de auditoría, esquema de base de datos y admin inicial. En arranques posteriores solo levanta el servidor. |

## Variables de entorno requeridas

Todas vienen del archivo `.env` en la raíz del repo:

| Variable | Para qué |
|---|---|
| `PI_ADMIN_USERNAME` | Nombre del admin inicial |
| `PI_ADMIN_PASSWORD` | Contraseña del admin inicial |
| `PI_PEPPER` | Valor secreto que se concatena a las contraseñas internas antes de hash |
| `PI_SECRET_KEY` | Llave de sesión de Flask |

Los valores académicos siguen el patrón `sia-<rol>-2026` documentado en el README raíz.

## Arranque

Desde la raíz del repositorio:

```bash
cd compose
docker compose --env-file ../.env build privacyidea
docker compose --env-file ../.env up -d privacyidea
cd ..
```

La primera vez el build tarda varios minutos porque compila dependencias nativas (`python-ldap`, `cryptography`). Los siguientes arranques son inmediatos.

La interfaz web queda disponible en `http://localhost:8080`.

## Verificación

```bash
./scripts/privacyidea-verify.sh
```

El script valida en orden:

1. El servicio responde en `http://localhost:8080/`.
2. El admin puede autenticarse vía API y obtener un token de sesión.
3. Lista los resolvers configurados (si los hay).
4. Valida que el resolver LDAP encuentra exactamente 6 usuarios.
5. Valida que el realm existe.

En los pasos 3 a 5, si la configuración aún no está hecha, el script imprime `PENDIENTE` y termina con éxito. Solo errores reales (servicio caído, admin que no autentica, conteo incorrecto) devuelven código distinto de cero.

## Configuración del resolver LDAP y del realm

Para que PrivacyIDEA pueda buscar usuarios en el mismo OpenLDAP, hay que crear un *LDAP resolver* y un *realm* que lo agrupe. La ruta recomendada es usar el script reproducible:

```bash
./scripts/privacyidea-configure.sh
./scripts/privacyidea-verify.sh
```

El script usa la API de PrivacyIDEA para crear o actualizar el resolver `sia-ldap`, crear el realm `sia` y marcarlo como realm por defecto. La configuración queda persistida en la base de datos SQLite.

También se puede hacer desde la interfaz web si se quiere revisar visualmente la configuración.

### Crear el resolver LDAP

1. Abrir `http://localhost:8080`, iniciar sesión con el admin (`admin` y el valor de `PI_ADMIN_PASSWORD`).
2. Ir a *Config*, luego *Users*, luego *New LDAP resolver*.
3. Rellenar los campos (los valores corresponden al árbol documentado en [`docs/arbol-ldap.md`](../docs/arbol-ldap.md)):

| Campo | Valor |
|---|---|
| Resolver name | `sia-ldap` |
| Server URI | `ldap://openldap` (nombre del contenedor en la red Docker) |
| Bind Type | Simple |
| Bind DN | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` |
| Bind Password | valor de `LDAP_SERVICE_PASSWORD` (por ejemplo `sia-svc-2026`) |
| Base DN | `dc=sia,dc=unam,dc=mx` |
| LoginName Attribute | `uid` |
| UserID Attribute | `entryUUID` |
| Search Filter | `(objectClass=inetOrgPerson)` |
| User Filter | `(&(uid={login})(objectClass=inetOrgPerson))` |

4. Probar la conexión con el botón de prueba. Debe devolver `Found 6 users`.
5. Guardar.

### Crear el realm

1. Ir a *Config*, luego *Realms*, luego *New realm*.
2. Nombre del realm: `sia`.
3. Asignar el resolver `sia-ldap`.
4. Marcar el realm como realm por defecto.

### Validar

Correr de nuevo `./scripts/privacyidea-verify.sh`. Debe terminar con `Todo OK` en los 5 pasos.

## Enrolar un token TOTP con FreeOTP

Pendiente de documentar en la fase siguiente.

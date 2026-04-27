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

La interfaz web queda disponible en `https://localhost:8443`.

## Verificación

```bash
./scripts/privacyidea-verify.sh
```

El script valida en orden:

1. El servicio responde en `https://localhost:8443/`.
2. El admin puede autenticarse vía API y obtener un token de sesión.
3. Lista los resolvers configurados (si los hay).
4. Valida que el resolver LDAP use LDAPS y verifique la CA local.
5. Valida que el resolver LDAP encuentra exactamente 6 usuarios.
6. Valida que el realm existe.

Si la configuración aún no está hecha, el script termina con código distinto de cero e indica correr `./scripts/privacyidea-configure.sh`.

## Configuración del resolver LDAP y del realm

Para que PrivacyIDEA pueda buscar usuarios en el mismo OpenLDAP, hay que crear un *LDAP resolver* y un *realm* que lo agrupe. La ruta recomendada es usar el script reproducible:

```bash
./scripts/privacyidea-configure.sh
./scripts/privacyidea-verify.sh
```

El script usa la API de PrivacyIDEA para crear o actualizar el resolver `sia-ldap`, crear el realm `sia` y marcarlo como realm por defecto. La configuración queda persistida en la base de datos SQLite.

También se puede hacer desde la interfaz web si se quiere revisar visualmente la configuración.

### Crear el resolver LDAP

1. Abrir `https://localhost:8443`, iniciar sesión con el admin (`admin` y el valor de `PI_ADMIN_PASSWORD`).
2. Ir a *Config*, luego *Users*, luego *New LDAP resolver*.
3. Rellenar los campos (los valores corresponden al árbol documentado en [`docs/arbol-ldap.md`](../docs/arbol-ldap.md)):

| Campo | Valor |
|---|---|
| Resolver name | `sia-ldap` |
| Server URI | `ldaps://openldap:636` (nombre del contenedor en la red Docker) |
| Bind Type | Simple |
| Bind DN | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` |
| Bind Password | valor de `LDAP_SERVICE_PASSWORD` (por ejemplo `sia-svc-2026`) |
| TLS verify | `True` |
| TLS version | `5` (TLS 1.2) |
| TLS CA file | `/etc/privacyidea/ssl/ca.crt` |
| Base DN | `dc=sia,dc=unam,dc=mx` |
| LoginName Attribute | `uid` |
| UserID Attribute | `entryUUID` |
| Search Filter | `(objectClass=inetOrgPerson)` |

4. Probar la conexión con el botón de prueba. Debe devolver `Found 6 users`.
5. Guardar.

### Crear el realm

1. Ir a *Config*, luego *Realms*, luego *New realm*.
2. Nombre del realm: `sia`.
3. Asignar el resolver `sia-ldap`.
4. Marcar el realm como realm por defecto.

### Validar

Correr de nuevo `./scripts/privacyidea-verify.sh`. Debe terminar con `Todo OK` en los 6 pasos.

## Enrolar un token TOTP con FreeOTP

El enrolamiento del token se hace una sola vez desde la interfaz web (porque produce un código QR que el usuario escanea con su teléfono). Después se valida desde la línea de comandos con `scripts/privacyidea-validate-otp.sh`, que usa el mismo endpoint `/validate/check` que invocará OwnCloud en la fase siguiente.

### Prerrequisito en el teléfono

Instalar **FreeOTP Authenticator** en el móvil:

- Android: [Play Store](https://play.google.com/store/apps/details?id=org.fedorahosted.freeotp)
- iOS: [App Store](https://apps.apple.com/us/app/freeotp-authenticator/id872559395)

### Enrolar el token desde la UI

1. Abrir `https://localhost:8443` e iniciar sesión como `admin`.
2. Ir a *Tokens*, luego *Enroll Token*.
3. Rellenar los campos:

| Campo | Valor |
|---|---|
| Token type | `TOTP` |
| Realm | `sia` |
| User | `usuario.desarrollo1` (o el usuario que se quiera enrolar) |
| OTP length | `6` |
| Hash algorithm | `SHA1` |
| Time step | `30` |

4. Hacer clic en *Enroll Token*. PrivacyIDEA genera un secreto, lo asocia al usuario y muestra un código QR.
5. Abrir FreeOTP en el móvil, tocar el ícono de agregar y escanear el QR. El token queda agregado con el nombre del usuario y empieza a generar códigos de 6 dígitos que rotan cada 30 segundos.

### Validar el primer código

Desde la laptop del proyecto, con el código que muestra FreeOTP en el móvil:

```bash
./scripts/privacyidea-validate-otp.sh usuario.desarrollo1 287543
```

### Prueba reproducible sin teléfono

Para validar que el flujo de 2FA funciona de punta a punta sin depender de un teléfono (útil para CI, para un compañero del equipo que no tenga FreeOTP instalado, y para diagnosticar la integración cuando algo falla), está el script `scripts/privacyidea-enroll-test-token.sh`:

```bash
./scripts/privacyidea-enroll-test-token.sh            # usuario.desarrollo1 por defecto
./scripts/privacyidea-enroll-test-token.sh usuario.seguridad2
```

Qué hace:

1. Se autentica como admin.
2. Borra el token de prueba previo (serial `TOTP_<usuario>`) si existe.
3. Llama a `POST /token/init` con `genkey=1`, de modo que la semilla la genera PrivacyIDEA (no hay secretos hardcodeados en el repo).
4. Imprime la URL `otpauth://` para que el equipo pueda escanear el QR con FreeOTP si quiere usarla en la demo.
5. Calcula el TOTP actual con Python estándar (`hmac`, `hashlib`, `struct`, `time`) a partir de la misma semilla.
6. Llama a `POST /validate/check` con `user`, `realm` y el OTP calculado. Si PrivacyIDEA acepta el código, el script termina con exit 0.

**Atención:** cada ejecución genera una semilla nueva. Si ya escaneaste el QR con FreeOTP, no vuelvas a correr el script para ese mismo usuario, porque invalidará el token que tiene el teléfono.

Se espera:

```
==> Validando OTP para 'usuario.desarrollo1@sia' contra https://localhost:8443
OK: PrivacyIDEA aceptó el OTP.
```

Exit 0 quiere decir que PrivacyIDEA aceptó el token; exit 1 significa que el código no coincidía (típicamente porque ya pasó la ventana de 30 segundos o el token no está asociado al usuario).

### Qué está pasando por detrás

El endpoint `POST /validate/check` recibe `user`, `realm` y `pass`, busca al usuario en el resolver (`sia-ldap` sobre OpenLDAP), localiza los tokens asignados y valida el código TOTP contra el secreto que se guardó al momento del enrolamiento. **Es el mismo endpoint** que invocará el plugin `twofactor_privacyidea` de OwnCloud en la Fase 5: cuando en la demo final un usuario teclee su OTP en OwnCloud, OwnCloud estará haciendo la misma llamada que hace este script.

### Casos de error útiles para la auditoría

Todos los intentos, correctos o fallidos, se escriben en la bitácora de PrivacyIDEA (`/var/log/privacyidea/privacyidea.log` dentro del contenedor y en la tabla `pidea_audit` de la base de datos). Un par de pruebas que vale la pena mostrar en la demo:

- Usuario sin token enrolado: `./scripts/privacyidea-validate-otp.sh usuario.desarrollo2 123456` devuelve rechazo con `authentication: REJECT`.
- OTP mal tecleado: se rechaza igual, pero aparece en auditoría con el usuario correcto y el motivo.
- Usuario inexistente en el LDAP: `./scripts/privacyidea-validate-otp.sh intruso 123456` devuelve rechazo por resolver que no encuentra al usuario.

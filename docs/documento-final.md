# Documento final operativo del proyecto

**Proyecto:** otp-secured-cloud\
**Materia:** Seguridad Informática Avanzada, FI-UNAM, semestre 2026-2\
**Fecha de cierre:** 2026-05-14\
**Estado:** funcional, validado y reproducible desde el repositorio

## 1. Resumen ejecutivo

El proyecto implementa un servicio de almacenamiento de archivos con autenticación de doble factor usando OpenLDAP, privacyIDEA, OwnCloud, MariaDB, Redis y Caddy. La solución separa las responsabilidades de forma clara:

| Capa | Componente | Función |
|---|---|---|
| Identificación | OpenLDAP | Mantiene los usuarios humanos y sus UIDs únicos |
| Autenticación, primer factor | OpenLDAP | Valida usuario y contraseña por LDAPS |
| Autenticación, segundo factor | privacyIDEA + app TOTP | Valida el código OTP asociado al usuario |
| Autorización | OwnCloud | Controla archivos, permisos y compartidos |
| Cifrado | OwnCloud Server Side Encryption | Guarda archivos cifrados en disco |
| Auditoría | Logs de OpenLDAP, privacyIDEA y OwnCloud | Evidencia complementaria no evaluable |

El profesor confirmó que la auditoría no será evaluada. Por eso la demo y las pruebas principales se enfocan en identificación, autenticación y autorización, manteniendo auditoría como evidencia complementaria.

La condición de éxito del proyecto es que una persona pueda clonar el repositorio, ejecutar un comando, levantar todo el laboratorio y validar los puntos evaluables sin configuración manual.

## 2. Arquitectura implementada

El stack corre en Docker Compose con seis servicios principales:

| Servicio | Contenedor | Rol |
|---|---|---|
| OpenLDAP | `otpsec-openldap` | Directorio LDAP con usuarios, cuenta de servicio y LDAPS |
| privacyIDEA | `otpsec-privacyidea` | Servidor OTP con resolver LDAP y realm `sia` |
| OwnCloud | `otpsec-owncloud-server` | Portal web, LDAP backend, plugin 2FA y cifrado |
| MariaDB | `otpsec-owncloud-db` | Base de datos de OwnCloud |
| Redis | `otpsec-owncloud-redis` | Cache y locking de OwnCloud |
| Caddy | `otpsec-owncloud-proxy` | TLS delante de OwnCloud en `https://localhost:9443` |

Las conexiones internas relevantes son:

1. OwnCloud consulta OpenLDAP por LDAPS para resolver y autenticar usuarios.
2. privacyIDEA consulta OpenLDAP por LDAPS mediante el resolver `sia-ldap`.
3. OwnCloud consulta privacyIDEA por HTTPS interno para validar el OTP.
4. El usuario final entra a OwnCloud por HTTPS mediante Caddy.

El proyecto usa una CA local generada por `scripts/generate-certs.sh`. Esa CA firma los certificados de OpenLDAP, privacyIDEA y OwnCloud. En laboratorio es normal que el navegador pida aceptar una excepción de certificado.

## 3. Directorio LDAP

La base del directorio es:

```text
dc=sia,dc=unam,dc=mx
```

El árbol tiene usuarios humanos y cuentas de servicio separadas:

```text
dc=sia,dc=unam,dc=mx
|-- ou=Usuarios
|   |-- ou=Desarrollo
|   |   |-- uid=usuario.desarrollo1
|   |   |-- uid=usuario.desarrollo2
|   |   `-- uid=usuario.desarrollo3
|   `-- ou=Seguridad
|       |-- uid=usuario.seguridad1
|       |-- uid=usuario.seguridad2
|       `-- uid=usuario.seguridad3
`-- ou=Servicios
    `-- cn=svc-owncloud
```

Decisiones importantes:

- Los seis usuarios humanos usan `objectClass=inetOrgPerson`.
- La cuenta `svc-owncloud` está separada para que no aparezca como usuario humano.
- La cuenta de servicio puede leer los atributos necesarios, pero no debe leer `userPassword`.
- Las contraseñas de usuarios se siembran como hashes `{SSHA}` en los LDIF.
- OpenLDAP publica LDAPS en `localhost:6636` para pruebas desde el host.

La validación automática vive en:

```bash
./scripts/ldap-verify.sh
```

Este script confirma bind de admin, conteo exacto de usuarios, lectura con cuenta de servicio, rechazo de credenciales inválidas y TLS LDAPS.

## 4. privacyIDEA y segundo factor

privacyIDEA se usa como servidor de tokens OTP. No mantiene una base de usuarios propia; lee los usuarios desde el mismo LDAP mediante:

| Elemento | Valor |
|---|---|
| Resolver | `sia-ldap` |
| Realm | `sia` |
| Conexión LDAP | `ldaps://openldap:636` |
| Cuenta de lectura | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` |

El token usado en la demo es TOTP:

- 6 dígitos.
- Ventana de 30 segundos.
- Algoritmo HMAC-SHA1.
- Compatible con FreeOTP, Proton Authenticator, Google Authenticator y apps TOTP equivalentes.

El teléfono no habla con privacyIDEA. El teléfono solo calcula el código a partir del secreto compartido. OwnCloud recibe el código del usuario y lo manda a privacyIDEA para decidir si es válido.

Scripts relevantes:

```bash
./scripts/privacyidea-configure.sh
./scripts/privacyidea-verify.sh
./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo2
./scripts/privacyidea-validate-otp.sh usuario.desarrollo1 <código>
```

Para la demo con teléfono real, el token de `usuario.desarrollo1` ya puede estar enrolado en Proton Authenticator. Si se vuelve a enrolar ese mismo usuario, se reemplaza el token anterior y el QR viejo deja de funcionar.

## 5. OwnCloud, login 2FA y autorización

OwnCloud es la aplicación visible para el usuario. En este proyecto cumple cuatro funciones:

1. Presenta el portal web de archivos.
2. Usa `user_ldap` para autenticar usuarios contra OpenLDAP.
3. Usa `twofactor_privacyidea` para pedir OTP después de la contraseña.
4. Administra permisos, compartidos y cifrado de archivos.

El flujo de login es:

1. El usuario entra a `https://localhost:9443`.
2. Escribe usuario LDAP y contraseña.
3. OwnCloud valida ese primer factor contra OpenLDAP.
4. Si la contraseña es correcta, OwnCloud redirige al challenge OTP.
5. El usuario abre Proton Authenticator o FreeOTP y copia el código actual.
6. OwnCloud manda ese código a privacyIDEA.
7. privacyIDEA valida el token del usuario en el realm `sia`.
8. Si el código es correcto, OwnCloud abre `/apps/files/`.

La cuenta `admin` de OwnCloud es local y de mantenimiento. No existe en el realm LDAP `sia`, por lo tanto queda excluida explícitamente del flujo OTP con `piexclude=1` y `piexcludegroups=admin`. La demo evaluable debe hacerse con usuarios LDAP, por ejemplo:

```text
usuario.desarrollo1 / sia-user-2026
```

## 6. Cifrado y archivos compartidos

OwnCloud tiene activado Server Side Encryption con master key. Eso significa que el contenido se guarda cifrado en el volumen de datos, aunque un usuario autorizado lo pueda leer en claro desde OwnCloud.

La evidencia concreta de cifrado en disco es que el archivo contiene una cabecera como:

```text
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

La prueba de compartidos valida que:

1. Un usuario emisor inicia sesión con LDAP + OTP.
2. El emisor sube un archivo.
3. OwnCloud guarda ese archivo cifrado en disco.
4. El emisor lo comparte con otro usuario mediante la API OCS.
5. El destinatario inicia sesión con LDAP + OTP.
6. El destinatario descarga el archivo y lo lee descifrado.

Esto demuestra que la autorización vive en OwnCloud y que el cifrado no rompe la lectura para usuarios autorizados.

## 7. Comando único de arranque

Desde un clon limpio del repositorio:

```bash
git clone git@github.com:chochy2001/otp-secured-cloud.git
cd otp-secured-cloud
./scripts/bootstrap.sh
```

Ese comando ejecuta:

1. Generación de certificados.
2. Build y arranque de Docker Compose.
3. Espera de healthchecks.
4. Configuración de privacyIDEA.
5. Configuración de OwnCloud.
6. Validación de LDAP.
7. Validación de privacyIDEA.
8. Validación de OwnCloud.
9. Prueba end-to-end de login LDAP + OTP.
10. Prueba de cifrado local.
11. Prueba de archivo compartido y lectura descifrada por destinatario.

Las pruebas automáticas usan `usuario.desarrollo2`, `usuario.desarrollo3` y `usuario.seguridad1` para no reemplazar el token físico de `usuario.desarrollo1`.

Si termina con `Listo`, el laboratorio está operativo.

Para una laptop donde el stack ya está construido:

```bash
./scripts/bootstrap.sh --no-build
```

Para confirmar salud sin correr las pruebas end-to-end:

```bash
./scripts/bootstrap.sh --no-build --skip-tests
```

## 8. Pruebas finales que confirman el cumplimiento

Si ya existe un token real en Proton Authenticator para `usuario.desarrollo1`, no se recomienda correr scripts automáticos con ese mismo usuario porque pueden rotar su token. Para pruebas automáticas usa otros usuarios.

Secuencia recomendada:

```bash
./scripts/ldap-verify.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo2
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

Interpretación:

| Comando | Resultado esperado | Evidencia |
|---|---|---|
| `ldap-verify.sh` | `Todo OK.` | LDAP tiene usuarios, ACL, LDAPS y rechazo de password incorrecto |
| `privacyidea-verify.sh` | `Todo OK.` | privacyIDEA responde, tiene resolver y realm correctos |
| `owncloud-verify.sh` | `Todo OK.` | OwnCloud ve LDAP, 2FA y cifrado |
| `owncloud-login-verify.sh usuario.desarrollo2` | `OK: archivo subido y cifrado en el volumen.` | Login LDAP + OTP y cifrado |
| `owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1` | `OK: usuario.seguridad1 descifró y leyó el archivo compartido.` | Autorización y compartidos |

Si cualquiera falla, el script imprime `ERROR:` y corta con código distinto de cero.

## 9. Demo manual recomendada

Usar esta demo para mostrar el sistema al profesor:

1. Abrir navegador en modo incógnito.
2. Entrar a `https://localhost:9443`.
3. Aceptar la advertencia de certificado si aparece.
4. Iniciar sesión con:
   ```text
   Usuario: usuario.desarrollo1
   Contraseña: sia-user-2026
   ```
5. Cuando OwnCloud pida OTP, abrir Proton Authenticator.
6. Usar el código actual de `TOTP_usuario_desarrollo1`.
7. Confirmar que abre la vista de archivos.
8. Subir un archivo, por ejemplo `demo-profe.txt`.
9. Compartirlo desde la UI con `usuario.seguridad1` o `usuario.seguridad2`.
10. Mostrar en terminal que el archivo está cifrado en disco:
    ```bash
    docker exec otpsec-owncloud-server head -c 80 \
      /mnt/data/files/usuario.desarrollo1/files/demo-profe.txt
    echo
    ```

Salida esperada:

```text
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

## 10. Mapeo directo a lo que pide el profesor

| Punto evaluable | Estado | Cómo se demuestra |
|---|---|---|
| Alta de usuarios en LDAP | Implementado | `ldap-verify.sh` confirma 6 usuarios humanos |
| Integración con privacyIDEA | Implementado | `privacyidea-verify.sh` confirma resolver `sia-ldap` y realm `sia` |
| Emisión de OTP desde app móvil | Implementado | QR `otpauth://` enrolado en Proton Authenticator o FreeOTP |
| Implementación de OwnCloud | Implementado | `owncloud-verify.sh` confirma OwnCloud 10.15, LDAP, 2FA y cifrado |
| Integración 2FA LDAP + OTP | Implementado | Login web con `usuario.desarrollo1` + contraseña + OTP |
| Autorización por aplicativo | Implementado | OwnCloud comparte archivos con usuarios autorizados |
| Cifrado de archivos compartidos | Implementado | `owncloud-share-verify.sh` valida lectura descifrada por destinatario |

## 11. Respuestas cortas para defender el proyecto

| Pregunta | Respuesta |
|---|---|
| ¿Dónde se autentica la contraseña? | En OpenLDAP, mediante bind por LDAPS. |
| ¿Dónde se valida el OTP? | En privacyIDEA, mediante el endpoint `/validate/check`. |
| ¿Qué hace Proton Authenticator o FreeOTP? | Solo calcula el TOTP localmente; no valida contra el servidor. |
| ¿Dónde vive la autorización? | En OwnCloud, con permisos y compartidos. |
| ¿Por qué LDAP no maneja permisos de carpetas? | Porque el profesor confirmó que LDAP autentica y OwnCloud autoriza. |
| ¿El archivo queda cifrado en disco? | Sí, se valida con la cabecera `HBEGIN:oc_encryption_module`. |
| ¿El cifrado protege contra el administrador del servidor? | No completamente; la master key vive en el servidor. Es una limitación declarada. |
| ¿Qué pasa si privacyIDEA cae? | El login 2FA falla. En producción se requeriría alta disponibilidad o una política de break-glass. |
| ¿Por qué `admin` no usa OTP? | Es una cuenta local de mantenimiento de OwnCloud y no existe en el realm LDAP `sia`. |

## 12. Limitaciones declaradas

El proyecto está hecho para laboratorio académico. No debe presentarse como sistema productivo sin hardening adicional.

Limitaciones conocidas:

- `.env` versionado con secretos académicos para reproducibilidad.
- Certificados autofirmados con CA local.
- Todos los usuarios de demo comparten la misma contraseña académica.
- Sin alta disponibilidad.
- Sin backup productivo.
- Sin rate limiting ni lockout avanzado.
- Cifrado con master key local, no cifrado extremo a extremo.

Estas limitaciones no contradicen el entregable; están documentadas para mostrar criterio técnico y honestidad de alcance.

## 13. Estado final

El proyecto queda en estado funcional y consistente:

- Servicios Docker saludables.
- LDAP operativo por LDAPS.
- privacyIDEA integrado al LDAP.
- Token TOTP compatible con app móvil.
- OwnCloud integrado con LDAP y privacyIDEA.
- Login 2FA probado.
- Cifrado de archivos activo.
- Compartidos probados con lectura descifrada por destinatario.
- Documentación, guion, presentación y pruebas listas.

La forma más segura de confirmar todo antes de presentar es:

```bash
git pull origin main
./scripts/ldap-verify.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo2
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

Con esas salidas en `OK`, el proyecto cumple lo pedido y está listo para mostrarse.

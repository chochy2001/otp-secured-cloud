# Auditoría: muestreo de eventos de control de acceso

Generado por `scripts/audit-capture.sh` el 2026-05-11T16:02:07 UTC.

**Nota sobre alcance:** el profesor confirmó por correo que la cuarta
capa (auditoría) no será evaluada. Este documento se mantiene como
complemento académico para ilustrar el marco de control de acceso de
cuatro capas que el profesor presentó en clase.

Este documento contiene extractos de logs reales de los tres
componentes del proyecto, capturados al disparar eventos clave
del flujo de autenticación. Sirve para que el equipo y, si lo
solicita, el evaluador entiendan dónde mirar en cada componente.

Componente | Fuente del log
---|---
OpenLDAP | `docker logs otpsec-openldap` (slapd a stdout/stderr)
PrivacyIDEA | `docker logs otpsec-privacyidea` y `/var/log/privacyidea/` dentro del contenedor
OwnCloud | `/mnt/data/files/owncloud.log` dentro del contenedor (JSON estructurado)

Las secciones siguientes muestran la salida directa, sin reescribir.

## 1. Login LDAP exitoso

Bind directo del usuario `usuario.seguridad1` con su contraseña LDAP. Cierra el primer factor de autenticación. Esperado en el log: BIND con `err=0`.

Marcador (UTC): `2026-05-11T16:02:07`

### OpenLDAP

```
6a01fd7a conn=8583 op=0 BIND dn="uid=usuario.seguridad1,ou=seguridad,ou=usuarios,dc=sia,dc=unam,dc=mx" method=128
6a01fd7a conn=8583 op=0 BIND dn="uid=usuario.seguridad1,ou=Seguridad,ou=Usuarios,dc=sia,dc=unam,dc=mx" mech=SIMPLE ssf=0
6a01fd7a conn=8583 op=0 RESULT tag=97 err=0 text=
```

## 2. Login LDAP fallido

Bind del mismo usuario con contraseña incorrecta. Esperado en el log: BIND con `err=49` (invalidCredentials).

Marcador (UTC): `2026-05-11T16:02:08`

### OpenLDAP

```
6a01fd7a conn=8583 op=0 BIND dn="uid=usuario.seguridad1,ou=seguridad,ou=usuarios,dc=sia,dc=unam,dc=mx" method=128
6a01fd7a conn=8583 op=0 BIND dn="uid=usuario.seguridad1,ou=Seguridad,ou=Usuarios,dc=sia,dc=unam,dc=mx" mech=SIMPLE ssf=0
6a01fd7a conn=8583 op=0 RESULT tag=97 err=0 text=
```

## 3. Enrolamiento de token TOTP

El admin de privacyIDEA crea un token TOTP para `usuario.seguridad1` con `genkey=1`. Esperado: una línea POST `/token/init` y respuesta 200 en el log de uwsgi/Flask.

Marcador (UTC): `2026-05-11T16:02:09`

### PrivacyIDEA

```
[2026-05-11 16:02:10,338][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,338][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,340][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,340][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
192.168.65.1 - - [11/May/2026 16:01:48] "DELETE /token/TOTP_usuario_desarrollo1 HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:48] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:57] "DELETE /token/TOTP_usuario_desarrollo1 HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:57] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:57] "DELETE /token/TOTP_usuario_seguridad1 HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:57] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:02:10] "DELETE /token/TOTP_AUDIT_usuario_seguridad1 HTTP/1.1" 404 -
192.168.65.1 - - [11/May/2026 16:02:10] "POST /token/init HTTP/1.1" 200 -
```

## 4. OTP correcto validado

El cliente (en producción sería OwnCloud) valida un OTP vigente contra `POST /validate/check`. Esperado: respuesta con `result.status=True` y `result.value=True`.

Marcador (UTC): `2026-05-11T16:02:31`

### PrivacyIDEA

```
[2026-05-11 16:02:10,338][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,338][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,338][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,340][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,340][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:31,750][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
172.18.0.6 - - [11/May/2026 16:01:49] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:57] "DELETE /token/TOTP_usuario_seguridad1 HTTP/1.1" 200 -
172.18.0.6 - - [11/May/2026 16:02:01] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [11/May/2026 16:02:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:02:10] "DELETE /token/TOTP_AUDIT_usuario_seguridad1 HTTP/1.1" 404 -
192.168.65.1 - - [11/May/2026 16:02:31] "POST /validate/check HTTP/1.1" 200 -
```

## 5. OTP incorrecto rechazado

Mismo endpoint con OTP `000000`. Esperado: `result.value=False`.

Marcador (UTC): `2026-05-11T16:02:32`

### PrivacyIDEA

```
[2026-05-11 16:02:10,338][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,340][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:10,340][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:31,750][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
[2026-05-11 16:02:33,017][1][281473261498784][INFO][privacyidea.lib.user:272] user 'usuario.seguridad1' found in resolver 'sia-ldap'
172.18.0.6 - - [11/May/2026 16:01:49] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:01:57] "DELETE /token/TOTP_usuario_seguridad1 HTTP/1.1" 200 -
172.18.0.6 - - [11/May/2026 16:02:01] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [11/May/2026 16:02:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:02:10] "DELETE /token/TOTP_AUDIT_usuario_seguridad1 HTTP/1.1" 404 -
192.168.65.1 - - [11/May/2026 16:02:31] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [11/May/2026 16:02:33] "POST /validate/check HTTP/1.1" 200 -
```

## 6. Login web OwnCloud LDAP + OTP exitoso

Flujo web completo: primer factor LDAP, redirección a selector 2FA, validación de OTP en el plugin `twofactor_privacyidea` y apertura de la vista de archivos.

Marcador (UTC): `2026-05-11T16:02:34`

### OwnCloud

```
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "POST", "url": "/login/challenge/privacyidea", "message": "token ec396358767f46883d611824a77b9e719c2037c6fdfac6c27894da8b50a533159ba5bd84da6e9ce3b331918816f96c85e1cd6817bc4c2d4a6816ab5c99b40ac6 with token id 60 found, validating"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "Send request to validate/check"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "With options: user=usuario.seguridad1, pass=395643, realm=sia"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "{\"detail\":{\"message\":\"matching 1 tokens\",\"otplen\":6,\"serial\":\"TOTP_AUDIT_usuario_seguridad1\",\"threadid\":281473261498784,\"type\":\"totp\"},\"id\":2,\"jsonrpc\":\"2.0\",\"result\":{\"authentication\":\"ACCEPT\",\"status\":true,\"value\":true},\"time\":1778515381.8919442,\"version\":\"privacyIDEA 3.10.2\",\"versionnumber\":\"3.10.2\",\"signature\":\"rsa_sha256_pss:46bb52a5ce652d2f938b5310ccd03f0774e8cb1a67183421049a9af9b2685e0a8c9f6d1236093894e0a12f2339caa6ebf6f4018194f7ce86cd963b3d22481e7c48e26d64215e50f6001d33b8ae3b4d7135388ddd0c0bf58e621b1ec948b6a20595f0ed9c74fec8f7494cac888fcb15becca60d283cc97826595dad46cf69029e6baced5400dfb3ec8676df41795c290c64aa5dc45c7faeeefed9fe17ebf72864aed0b730a4042af3bed3b476a58ac1720bc7edbdf258fa2adcf2e426b34c015c37360223916906703fadfe86a42ce3e25d8c518b48101426669658d71d9ef554c6a98fe0747b4c8f75ba08d9b97901a60ad8667c411705e4325e70918bf0d627\"}"}
{"reqId": "mVjA6vFsdBP933HMEZQZ", "level": 0, "time": "2026-05-11T16:03:01+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "privacyIDEA: User authenticated successfully!"}
```

## 7. Login web OwnCloud con OTP rechazado

Mismo flujo que el caso 6 pero el OTP enviado al plugin es `000000`. Esperado: el plugin `twofactor_privacyidea` redirige al selector de challenge y la sesión NO se eleva a la vista de archivos.

Marcador (UTC): `2026-05-11T16:03:03`

### OwnCloud

```
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "POST", "url": "/login/challenge/privacyidea", "message": "token 2edfb6c9afad94babe63a8c0eeb9a31bd92a97bc3f29c23e8dec0f00d104e39a186e1f0ce4df00fc007432f30c0348c5926e744752804da4fa9fd9cb50554f28 with token id 61 found, validating"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "Send request to validate/check"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "With options: user=usuario.seguridad1, pass=000000, realm=sia"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "{\"detail\":{\"message\":\"wrong otp value\",\"threadid\":281473261498784},\"id\":2,\"jsonrpc\":\"2.0\",\"result\":{\"authentication\":\"REJECT\",\"status\":true,\"value\":false},\"time\":1778515383.7882419,\"version\":\"privacyIDEA 3.10.2\",\"versionnumber\":\"3.10.2\",\"signature\":\"rsa_sha256_pss:2c3e4aa96067eede43a838b2206f1a0a983bc3dd9ab5c3202ac38945f004916dd1fabac2a65423f1c326cd063bf62563edf1aa9f29666adb5ee5d198f5659f62cdd9bc45c6a76cdd65691466fe9e4033fd255aa0a0ef23bb689116acbb92c07f7471dba86c8ff7acd69340b75875d0ef8ac961829393e4e9778a911b6ee640a824e214cd92ed2c904c68696bb1ebee9611d743c5c0463cac5cf9f445d924a1e3b29bdb6676061190f9898a3ca87fc59681561a982f0db653a37195188a422c52d41ef3746db8ce783487bc2fe2a091c3f60a873e09e44eb6f4cf16a630a303c316ee5977d611d34d0b3b697337cfc32f0d8e6634a7a50f5cabe7d8d3bf0b3db5\"}"}
{"reqId": "01avgyLjYQm1nwPnhLxT", "level": 0, "time": "2026-05-11T16:03:03+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "privacyIDEA:wrong otp value"}
```

## 8. Acceso a archivo por WebDAV

Subida (PUT) y descarga (GET) de `audit-demo.txt` por el usuario autenticado. Esperado: dos peticiones WebDAV registradas con código 2xx; el cifrado del lado servidor es transparente.

Marcador (UTC): `2026-05-11T16:03:31`

### OwnCloud

```
{"reqId": "l6xKnhSXunBUWHZiv8ma", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "GET", "url": "/login/selectchallenge", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "I7qzohWZZKof8nVOskm7", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/login/challenge/privacyidea", "message": "token 8206edd7cb512cb700ed7a557cd81d66905c41248fc26317593cccdfb81ed2f5f6d16f575e97bea86a699397a7a0648ecb3d8193f70b3eddc92c6f8d709d3b29 with token id 62 found, validating"}
{"reqId": "I7qzohWZZKof8nVOskm7", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/login/challenge/privacyidea", "message": "token 8206edd7cb512cb700ed7a557cd81d66905c41248fc26317593cccdfb81ed2f5f6d16f575e97bea86a699397a7a0648ecb3d8193f70b3eddc92c6f8d709d3b29 with token id 62 found, validating"}
{"reqId": "I7qzohWZZKof8nVOskm7", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/login/challenge/privacyidea", "message": "token 8206edd7cb512cb700ed7a557cd81d66905c41248fc26317593cccdfb81ed2f5f6d16f575e97bea86a699397a7a0648ecb3d8193f70b3eddc92c6f8d709d3b29 with token id 62 found, validating"}
{"reqId": "I7qzohWZZKof8nVOskm7", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "GET", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "I7qzohWZZKof8nVOskm7", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "privacyIDEA", "method": "GET", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "veD9QIw9kUdqPxGyUJYo", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "PUT", "url": "/remote.php/webdav/audit-demo.txt", "message": "token 8206edd7cb512cb700ed7a557cd81d66905c41248fc26317593cccdfb81ed2f5f6d16f575e97bea86a699397a7a0648ecb3d8193f70b3eddc92c6f8d709d3b29 with token id 62 found, validating"}
{"reqId": "4KnCtTtAPCiCb9MwK3tH", "level": 0, "time": "2026-05-11T16:03:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.seguridad1", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/remote.php/webdav/audit-demo.txt", "message": "token 8206edd7cb512cb700ed7a557cd81d66905c41248fc26317593cccdfb81ed2f5f6d16f575e97bea86a699397a7a0648ecb3d8193f70b3eddc92c6f8d709d3b29 with token id 62 found, validating"}
```

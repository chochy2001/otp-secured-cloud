# Auditoría: muestreo de eventos de control de acceso

Generado por `scripts/audit-capture.sh` el 2026-05-04T17:45:47 UTC.

Este documento contiene extractos de logs reales de los tres
componentes del proyecto, capturados al disparar eventos clave
del flujo de autenticación. Sirve como evidencia de la cuarta
capa del control de acceso (auditoría) y para que el equipo y
el evaluador entiendan dónde mirar en cada componente.

Componente | Fuente del log
---|---
OpenLDAP | `docker logs otpsec-openldap` (slapd a stdout/stderr)
PrivacyIDEA | `docker logs otpsec-privacyidea` y `/var/log/privacyidea/` dentro del contenedor
OwnCloud | `/mnt/data/files/owncloud.log` dentro del contenedor (JSON estructurado)

Las secciones siguientes muestran la salida directa, sin reescribir.

## 1. Login LDAP exitoso

Bind directo del usuario `usuario.desarrollo3` con su contraseña LDAP. Cierra el primer factor de autenticación. Esperado en el log: BIND con `err=0`.

Marcador (UTC): `2026-05-04T17:45:48`

### OpenLDAP

```
69f8db4c conn=2022 op=0 BIND dn="uid=usuario.desarrollo3,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" method=128
69f8db4c conn=2022 op=0 BIND dn="uid=usuario.desarrollo3,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" mech=SIMPLE ssf=0
69f8db4c conn=2022 op=0 RESULT tag=97 err=0 text=
```

## 2. Login LDAP fallido

Bind del mismo usuario con contraseña incorrecta. Esperado en el log: BIND con `err=49` (invalidCredentials).

Marcador (UTC): `2026-05-04T17:45:49`

### OpenLDAP

```
69f8db4c conn=2022 op=0 BIND dn="uid=usuario.desarrollo3,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" method=128
69f8db4c conn=2022 op=0 BIND dn="uid=usuario.desarrollo3,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" mech=SIMPLE ssf=0
69f8db4c conn=2022 op=0 RESULT tag=97 err=0 text=
69f8db4d conn=2024 op=0 BIND dn="uid=usuario.desarrollo3,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" method=128
69f8db4d conn=2024 op=0 RESULT tag=97 err=49 text=
```

## 3. Enrolamiento de token TOTP

El admin de privacyIDEA crea un token TOTP para `usuario.desarrollo3` con `genkey=1`. Esperado: una línea POST `/token/init` y respuesta 200 en el log de uwsgi/Flask.

Marcador (UTC): `2026-05-04T17:45:50`

### PrivacyIDEA

```
192.168.65.1 - - [04/May/2026 17:32:55] "DELETE /token/TOTP_AUDIT_usuario_desarrollo2 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:32:55] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:34:37] "DELETE /token/TOTP_AUDIT_usuario_desarrollo2 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:34:37] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:36] "DELETE /token/TOTP_usuario_desarrollo3 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:45:37] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:41] "DELETE /token/TOTP_usuario_desarrollo2 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:45:41] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:42] "DELETE /token/TOTP_usuario_seguridad2 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:45:42] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:50] "DELETE /token/TOTP_AUDIT_usuario_desarrollo3 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:45:50] "POST /token/init HTTP/1.1" 200 -
```

## 4. OTP correcto validado

El cliente (en producción sería OwnCloud) valida un OTP vigente contra `POST /validate/check`. Esperado: respuesta con `result.status=True` y `result.value=True`.

Marcador (UTC): `2026-05-04T17:46:01`

### PrivacyIDEA

```
172.18.0.6 - - [04/May/2026 17:33:32] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:35:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:35:03] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:35:32] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:35:34] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:36:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:36] "DELETE /token/TOTP_usuario_desarrollo3 HTTP/1.1" 404 -
172.18.0.6 - - [04/May/2026 17:45:38] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:45:43] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:45:44] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:50] "DELETE /token/TOTP_AUDIT_usuario_desarrollo3 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:46:01] "POST /validate/check HTTP/1.1" 200 -
```

## 5. OTP incorrecto rechazado

Mismo endpoint con OTP `000000`. Esperado: `result.value=False`.

Marcador (UTC): `2026-05-04T17:46:02`

### PrivacyIDEA

```
192.168.65.1 - - [04/May/2026 17:35:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:35:03] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:35:32] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:35:34] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:36:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:36] "DELETE /token/TOTP_usuario_desarrollo3 HTTP/1.1" 404 -
172.18.0.6 - - [04/May/2026 17:45:38] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:45:43] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:45:44] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:45:50] "DELETE /token/TOTP_AUDIT_usuario_desarrollo3 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:46:01] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:46:02] "POST /validate/check HTTP/1.1" 200 -
```

## 6. Login web OwnCloud LDAP + OTP exitoso

Flujo web completo: primer factor LDAP, redirección a selector 2FA, validación de OTP en el plugin `twofactor_privacyidea` y apertura de la vista de archivos.

Marcador (UTC): `2026-05-04T17:46:03`

### OwnCloud

```
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "POST", "url": "/login/challenge/privacyidea", "message": "token 5ab88d8cac846d6301d81b24234c0a490bf56d3607a7a07b6ebcc98268fd09976f8129b866c0698ebf4b467e347c6f5b94316596c199211d34a8d8b9bb5ee1dd with token id 33 found, validating"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "Send request to validate/check"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "With options: user=usuario.desarrollo3, pass=216472, realm=sia"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "{\"detail\":{\"message\":\"matching 1 tokens\",\"otplen\":6,\"serial\":\"TOTP_AUDIT_usuario_desarrollo3\",\"threadid\":281473578103200,\"type\":\"totp\"},\"id\":2,\"jsonrpc\":\"2.0\",\"result\":{\"authentication\":\"ACCEPT\",\"status\":true,\"value\":true},\"time\":1777916791.4361217,\"version\":\"privacyIDEA 3.10.2\",\"versionnumber\":\"3.10.2\",\"signature\":\"rsa_sha256_pss:2c85c1e95d64604e414293bb45e06468d2fe5cdc85a464d41bda9dba862b40557e67f4d8c5c0ffcc109f8d942670d11bbc7dc36891aea21c3acef55982716ec985615d95861613e02320451cea37818a9a8ca59ea7852d92ef897e7365f8761de794aa1d266c73331ce2d21f92a8eb30a01cbbed210ce53ca52996c5236ea02245742e2574f29dbaad7e33f4911d2e8ebbf56a74e4638fba8f0214931a8360d7082c8b298cd4b451f34cf6db25170c3e4a9c47aa7c2d0b01e32aa413238d62f069630d003710a63afe5cd8009534159b27f5031310445867f74587e0de3e1b0dda73555dfdfc94415c26feb234a25e2505672ef111e5f37677091610cba80bb9\"}"}
{"reqId": "0CgGl7M2TmTP91DFkZwQ", "level": 0, "time": "2026-05-04T17:46:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "privacyIDEA: User authenticated successfully!"}
```

## 7. Login web OwnCloud con OTP rechazado

Mismo flujo que el caso 6 pero el OTP enviado al plugin es `000000`. Esperado: el plugin `twofactor_privacyidea` redirige al selector de challenge y la sesión NO se eleva a la vista de archivos.

Marcador (UTC): `2026-05-04T17:46:32`

### OwnCloud

```
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "POST", "url": "/login/challenge/privacyidea", "message": "token 761253fdf997600b2ace45e79c3695fa21b90a8c72ea494d4447d8c9127051d364850dd45ad48effecb025d2d2fd8db90c01f72f01f59b471abbd855a3eeed07 with token id 34 found, validating"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "Send request to validate/check"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "With options: user=usuario.desarrollo3, pass=000000, realm=sia"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "{\"detail\":{\"message\":\"wrong otp value\",\"threadid\":281473578103200},\"id\":2,\"jsonrpc\":\"2.0\",\"result\":{\"authentication\":\"REJECT\",\"status\":true,\"value\":false},\"time\":1777916793.3082309,\"version\":\"privacyIDEA 3.10.2\",\"versionnumber\":\"3.10.2\",\"signature\":\"rsa_sha256_pss:3f42abff136063b0aba0bf0160360b9cb4ea22f740e48e8e16bd1b4761528b9e6692018a419671eecf1752ea64359c60b14467d2313a31cd4dc193e511f74f374202e848df88dc7ad7e5badc22e443f67dc2d16b7cc1b2bcdde106c186100d46f88af2fe67ced98c19ef1cfa38b80b82e68d155c76f95615bd6f8c8e8eac88554c5968aa1f1bb2a459842b552ac1f1c36540fa58781bcaf5856a557d6d249090656852b6e45f75a66d30ab684604e36e30829952444c65ca17190bb1c1a6afbb3411f7c2b4142189a5004d9f0c8a872d26dbee7aa130f80215ffd22f627898fcea69ef586fce4ca44150ba2de7f57c0c1437e8cff72dca1de301bcf3a1084505\"}"}
{"reqId": "DFq6jr89CmjU4sc6010E", "level": 0, "time": "2026-05-04T17:46:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "privacyIDEA:wrong otp value"}
```

## 8. Acceso a archivo por WebDAV

Subida (PUT) y descarga (GET) de `audit-demo.txt` por el usuario autenticado. Esperado: dos peticiones WebDAV registradas con código 2xx; el cifrado del lado servidor es transparente.

Marcador (UTC): `2026-05-04T17:47:02`

### OwnCloud

```
{"reqId": "aQfQLgKRjP7RfSUQ6D9Q", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "GET", "url": "/login/selectchallenge", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "7hoAYWv9BGMoRliPsqpL", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/login/challenge/privacyidea", "message": "token 75025feedf76cabef5541d7c91e1413cb61d9fe9b31d1c988cadeb368a4c5c657724e07c1dd1d09c830ab6831e127c47000f658c3c9a8c18f633804ec986befa with token id 35 found, validating"}
{"reqId": "7hoAYWv9BGMoRliPsqpL", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/login/challenge/privacyidea", "message": "token 75025feedf76cabef5541d7c91e1413cb61d9fe9b31d1c988cadeb368a4c5c657724e07c1dd1d09c830ab6831e127c47000f658c3c9a8c18f633804ec986befa with token id 35 found, validating"}
{"reqId": "7hoAYWv9BGMoRliPsqpL", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/login/challenge/privacyidea", "message": "token 75025feedf76cabef5541d7c91e1413cb61d9fe9b31d1c988cadeb368a4c5c657724e07c1dd1d09c830ab6831e127c47000f658c3c9a8c18f633804ec986befa with token id 35 found, validating"}
{"reqId": "7hoAYWv9BGMoRliPsqpL", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "GET", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "7hoAYWv9BGMoRliPsqpL", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "privacyIDEA", "method": "GET", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "itXcKmf4BZ0IgZERipcl", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "PUT", "url": "/remote.php/webdav/audit-demo.txt", "message": "token 75025feedf76cabef5541d7c91e1413cb61d9fe9b31d1c988cadeb368a4c5c657724e07c1dd1d09c830ab6831e127c47000f658c3c9a8c18f633804ec986befa with token id 35 found, validating"}
{"reqId": "aIuPWKs0tYi7vqukhI4A", "level": 0, "time": "2026-05-04T17:47:02+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo3", "app": "OC\\User\\Session::validateToken", "method": "GET", "url": "/remote.php/webdav/audit-demo.txt", "message": "token 75025feedf76cabef5541d7c91e1413cb61d9fe9b31d1c988cadeb368a4c5c657724e07c1dd1d09c830ab6831e127c47000f658c3c9a8c18f633804ec986befa with token id 35 found, validating"}
```

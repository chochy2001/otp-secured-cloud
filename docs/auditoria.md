# Auditoría: muestreo de eventos de control de acceso

Generado por `scripts/audit-capture.sh` el 2026-05-04T19:04:46 UTC.

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

Bind directo del usuario `usuario.desarrollo2` con su contraseña LDAP. Cierra el primer factor de autenticación. Esperado en el log: BIND con `err=0`.

Marcador (UTC): `2026-05-04T19:04:47`

### OpenLDAP

```
69f8edcf conn=4398 op=0 BIND dn="uid=usuario.desarrollo2,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" method=128
69f8edcf conn=4398 op=0 BIND dn="uid=usuario.desarrollo2,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" mech=SIMPLE ssf=0
69f8edcf conn=4398 op=0 RESULT tag=97 err=0 text=
```

## 2. Login LDAP fallido

Bind del mismo usuario con contraseña incorrecta. Esperado en el log: BIND con `err=49` (invalidCredentials).

Marcador (UTC): `2026-05-04T19:04:48`

### OpenLDAP

```
69f8edcf conn=4398 op=0 BIND dn="uid=usuario.desarrollo2,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" method=128
69f8edcf conn=4398 op=0 BIND dn="uid=usuario.desarrollo2,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" mech=SIMPLE ssf=0
69f8edcf conn=4398 op=0 RESULT tag=97 err=0 text=
69f8edd0 conn=4400 op=0 BIND dn="uid=usuario.desarrollo2,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" method=128
69f8edd0 conn=4400 op=0 RESULT tag=97 err=49 text=
```

## 3. Enrolamiento de token TOTP

El admin de privacyIDEA crea un token TOTP para `usuario.desarrollo2` con `genkey=1`. Esperado: una línea POST `/token/init` y respuesta 200 en el log de uwsgi/Flask.

Marcador (UTC): `2026-05-04T19:04:49`

### PrivacyIDEA

```
[2026-05-04 19:04:49,931][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,931][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
192.168.65.1 - - [04/May/2026 17:59:15] "DELETE /token/TOTP_usuario_desarrollo3 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:59:16] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 17:59:16] "DELETE /token/TOTP_usuario_seguridad3 HTTP/1.1" 404 -
192.168.65.1 - - [04/May/2026 17:59:16] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 18:34:59] "DELETE /token/TOTP_usuario_desarrollo1 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 18:34:59] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 18:35:00] "DELETE /token/TOTP_usuario_seguridad2 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 18:35:00] "POST /token/init HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:04:49] "DELETE /token/TOTP_AUDIT_usuario_desarrollo2 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:04:50] "POST /token/init HTTP/1.1" 200 -
```

## 4. OTP correcto validado

El cliente (en producción sería OwnCloud) valida un OTP vigente contra `POST /validate/check`. Esperado: respuesta con `result.status=True` y `result.value=True`.

Marcador (UTC): `2026-05-04T19:05:01`

### PrivacyIDEA

```
[2026-05-04 19:04:49,928][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,928][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,928][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,931][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,931][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:05:01,420][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
172.18.0.6 - - [04/May/2026 17:59:17] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:59:18] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 18:35:01] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 18:35:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:04:49] "DELETE /token/TOTP_AUDIT_usuario_desarrollo2 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:05:01] "POST /validate/check HTTP/1.1" 200 -
```

## 5. OTP incorrecto rechazado

Mismo endpoint con OTP `000000`. Esperado: `result.value=False`.

Marcador (UTC): `2026-05-04T19:05:02`

### PrivacyIDEA

```
[2026-05-04 19:04:49,928][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,931][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:04:49,931][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:05:01,420][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
[2026-05-04 19:05:02,692][1][281473578103200][INFO][privacyidea.lib.user:272] user 'usuario.desarrollo2' found in resolver 'sia-ldap'
172.18.0.6 - - [04/May/2026 17:59:17] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 17:59:18] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 18:35:01] "POST /validate/check HTTP/1.1" 200 -
172.18.0.6 - - [04/May/2026 18:35:02] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:04:49] "DELETE /token/TOTP_AUDIT_usuario_desarrollo2 HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:05:01] "POST /validate/check HTTP/1.1" 200 -
192.168.65.1 - - [04/May/2026 19:05:02] "POST /validate/check HTTP/1.1" 200 -
```

## 6. Login web OwnCloud LDAP + OTP exitoso

Flujo web completo: primer factor LDAP, redirección a selector 2FA, validación de OTP en el plugin `twofactor_privacyidea` y apertura de la vista de archivos.

Marcador (UTC): `2026-05-04T19:05:04`

### OwnCloud

```
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "OC\\User\\Session::validateToken", "method": "POST", "url": "/login/challenge/privacyidea", "message": "token 596c1b45fba43cb1b1784c462327a8272afa8223a544d2ab195e8c395320ce7d01026445f11e78df5928a0831d81fe3bc50330151cdb38537289ace7f7dcd0fe with token id 40 found, validating"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "Send request to validate/check"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "With options: user=usuario.desarrollo2, pass=866034, realm=sia"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "{\"detail\":{\"message\":\"matching 1 tokens\",\"otplen\":6,\"serial\":\"TOTP_AUDIT_usuario_desarrollo2\",\"threadid\":281473578103200,\"type\":\"totp\"},\"id\":2,\"jsonrpc\":\"2.0\",\"result\":{\"authentication\":\"ACCEPT\",\"status\":true,\"value\":true},\"time\":1777921531.608472,\"version\":\"privacyIDEA 3.10.2\",\"versionnumber\":\"3.10.2\",\"signature\":\"rsa_sha256_pss:10cf4306ac16c43c62b51952881842da40a16044e606dbbc6e370220902f4005f947eae7dcde18572bb144d7bab6408d425efd667b424081e6d415b0bc8736659fea4761c5c51bf20da955e7ddb1ac01109d4e5af538c67c833cae9f2d6fc5b38047937f94a4868cca5cfe2136d1bd5095c0668372f8148ea4f121631b5a0a0cdea8c350d98ff306b1bd47625bd926db903b992f7474a0bdcdc5a97e9b803def13fa4458520202eb0847ae3f390c7529038be27f8866cbed2a05cad2efc78005dcf33bbca457d91e6eaa3063eeb6710f5b63572857148e1c2bc77e21ba92432eec7a030c16822a9c8ef5e7d4f0f8f77bbdae96e8e23f76cdaca95cfabb0fe7e7\"}"}
{"reqId": "piNzt1m8hMR8rxfQRPO1", "level": 0, "time": "2026-05-04T19:05:31+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "privacyIDEA: User authenticated successfully!"}
```

## 7. Login web OwnCloud con OTP rechazado

Mismo flujo que el caso 6 pero el OTP enviado al plugin es `000000`. Esperado: el plugin `twofactor_privacyidea` redirige al selector de challenge y la sesión NO se eleva a la vista de archivos.

Marcador (UTC): `2026-05-04T19:05:32`

### OwnCloud

```
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "OC\\User\\Session::validateToken", "method": "POST", "url": "/login/challenge/privacyidea", "message": "token f589cdafbf07bffb184ff3223f24ad8aeac13f582ca0626bb85c432202a7ea2fdd13689e53e7e19cfbcbaca259f4d87d09a39c2d54f38473ad9c495fc42929f6 with token id 41 found, validating"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "[isTwoFactorAuthEnabledForUser] User needs 2FA"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "Send request to validate/check"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "With options: user=usuario.desarrollo2, pass=000000, realm=sia"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "{\"detail\":{\"message\":\"wrong otp value\",\"threadid\":281473578103200},\"id\":2,\"jsonrpc\":\"2.0\",\"result\":{\"authentication\":\"REJECT\",\"status\":true,\"value\":false},\"time\":1777921533.451947,\"version\":\"privacyIDEA 3.10.2\",\"versionnumber\":\"3.10.2\",\"signature\":\"rsa_sha256_pss:173969f3332b0f3a11fa87ab6fb882a90075976806d4af7a57b9629a41eade27aa82583f2d8e03dfcc5f4c52d03230a6b116dbce9cbd8feb249a3a11f3ccb4626f9843d92dcef895565c87e4f133b2ae846c32b4e3254bf2bb1dc1db7b22034e27b0370678f253dde78445f310a0a3ae9c4412174bc4c12a23b4ecfe4b7644d88b0083b7455afa3f63f4055c3d4531ca42c1eb344ba09a1db6db6362e64dd52c391bf3a20d7d0f0563d6b909c71e2e31041e241e2a8554161f7be64ed94e09e56182f3241e364a33d62d37da4d1a792cde36c26565b9ce814e1c9325840b94eadd7e33189387b94df928dfa302e64ae439205e579590e36a84b8ce244a584ecb\"}"}
{"reqId": "fA940bMzoNSvXHQOAgjA", "level": 0, "time": "2026-05-04T19:05:33+00:00", "remoteAddr": "172.18.0.7", "user": "usuario.desarrollo2", "app": "privacyIDEA", "method": "POST", "url": "/login/challenge/privacyidea", "message": "privacyIDEA:wrong otp value"}
```

## 8. Acceso a archivo por WebDAV

Subida (PUT) y descarga (GET) de `audit-demo.txt` por el usuario autenticado. Esperado: dos peticiones WebDAV registradas con código 2xx; el cifrado del lado servidor es transparente.

Marcador (UTC): `2026-05-04T19:06:01`

### OwnCloud

```
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Mark to expire /audit-demo.txt next version should be 1777912562 or smaller. (prevTimestamp: 1777916162; step: 3600"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Mark to expire /audit-demo.txt next version should be 1777912562 or smaller. (prevTimestamp: 1777916162; step: 3600"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Mark to expire /audit-demo.txt next version should be 1777912562 or smaller. (prevTimestamp: 1777916162; step: 3600"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Expire: /audit-demo.txt.v1777916012"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Expire: /audit-demo.txt.v1777915940"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Expire: /audit-demo.txt.v1777915771"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 1, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "files_versions", "method": "--", "url": "--", "message": "Expire: /audit-demo.txt.v1777915564"}
{"reqId": "8NEG0dscDJueQlgk2Zci", "level": 0, "time": "2026-05-04T19:06:02+00:00", "remoteAddr": "", "user": "--", "app": "cron", "method": "--", "url": "--", "message": "Finished background job, the job took : 0 seconds, this job is an instance of class : OC\\Command\\CommandJob with arguments : O:33:\"OCA\\Files_Versions\\Command\\Expire\":2:{s:43:\"\u0000OCA\\Files_Versions\\Command\\Expire\u0000fileName\";s:15:\"/audit-demo.txt\";s:39:\"\u0000OCA\\Files_Versions\\Command\\Expire\u0000user\";s:19:\"usuario.desarrollo2\";}"}
```

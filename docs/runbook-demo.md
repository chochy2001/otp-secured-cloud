# Runbook de la demo: copiar y pegar

Guía para correr la demo de principio a fin. Cada paso es un bloque para copiar
y pegar tal cual. Sigue el orden de arriba hacia abajo.

## Referencia rápida

Todos los comandos se corren desde la raíz del repositorio. Empieza siempre con:

```bash
cd /Users/jorge/Documents/Escuela/SIA/Proyecto_Final
```

Usuarios y para qué se usan:

- Teléfono (FreeOTP, manual): `usuario.desarrollo1` y `usuario.desarrollo2`. Contraseña `sia-user-2026`.
- Pruebas automáticas (scripts, sin teléfono): `usuario.seguridad2`, `usuario.desarrollo3`, `usuario.seguridad1`.

Regla: los scripts automáticos nunca tocan a `desarrollo1` ni `desarrollo2`, así que sus tokens del teléfono no se rotan.

---

## Bloque 0: Arrancar el laboratorio

### 1. Arrancar Docker y esperar a que esté listo

```bash
open -a Docker
until docker info >/dev/null 2>&1; do sleep 2; done; echo "Docker listo"
```

### 2. Levantar el stack (sin reconstruir, sin pruebas)

```bash
./scripts/bootstrap.sh --no-build --skip-tests
```

Levanta los seis contenedores, espera a que estén `healthy` y reaplica la configuración. Termina con `Listo`.

### 3. Confirmar los seis contenedores arriba

```bash
docker compose -f compose/docker-compose.yml --env-file .env ps
```

Los seis deben decir `Up` y `healthy`.

---

## Bloque 1: Teléfono (segundo factor en vivo)

Enrolas dos usuarios en FreeOTP con el mismo procedimiento. Para cada uno:
enrolar + QR en un bloque, escanear, validar.

### 4. usuario.desarrollo1: enrolar y generar QR

```bash
URL=$(./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo1 2>&1 | grep -oE 'otpauth://[^ ]+' | head -1)
echo "URL activa: $URL"
qrencode -o /tmp/otp-qr1.png -s 10 "$URL"
open /tmp/otp-qr1.png
```

Enrola el token, arma el QR con la URL de esa misma corrida y lo abre en Vista Previa. El secreto del QR y el de privacyIDEA quedan iguales porque salen del mismo enrolamiento.

### 5. usuario.desarrollo1: escanear y validar

En FreeOTP toca "+", escanea el QR. Si ya había una entrada `TOTP_usuario_desarrollo1`, bórrala antes. Luego, con los 6 dígitos que muestre el teléfono:

```bash
./scripts/privacyidea-validate-otp.sh usuario.desarrollo1 LOS_6_DIGITOS
```

Debe decir `OK: PrivacyIDEA aceptó el OTP.`.

### 6. usuario.desarrollo2: enrolar y generar QR

```bash
URL=$(./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo2 2>&1 | grep -oE 'otpauth://[^ ]+' | head -1)
echo "URL activa: $URL"
qrencode -o /tmp/otp-qr2.png -s 10 "$URL"
open /tmp/otp-qr2.png
```

### 7. usuario.desarrollo2: escanear y validar

En FreeOTP toca "+", escanea el QR (queda la entrada `TOTP_usuario_desarrollo2`). Luego, con los 6 dígitos del teléfono:

```bash
./scripts/privacyidea-validate-otp.sh usuario.desarrollo2 LOS_6_DIGITOS
```

Debe decir `OK: PrivacyIDEA aceptó el OTP.`.

Trampa a evitar: pega cada bloque de enrolar+QR completo y de una vez. No mezcles una URL o un secreto de otra corrida; si el QR trae un secreto distinto al de privacyIDEA, la validación falla con `wrong otp value`.

---

## Bloque 2: Demo en la terminal (los puntos del profesor, sin teléfono)

Estos scripts usan usuarios de prueba y no tocan tus tokens del teléfono. Pausa unos segundos tras cada `OK` o `Todo OK` para que el grupo lo lea.

### 8. Usuarios dados de alta en LDAP (punto i)

```bash
./scripts/ldap-verify.sh
```

Termina con `Todo OK.` (8 checks).

### 8b. Dar de alta un usuario nuevo en vivo (para el profesor / demo)

Muestra cómo se crea un usuario nuevo de manera integral (LDAP + Sincronización en OwnCloud + Token TOTP en PrivacyIDEA) en un solo comando de forma automatizada y sin errores. Tienes dos opciones para correrlo:

#### Opción A: Modo Interactivo (Paso a paso guiado)
```bash
./scripts/add-user-2fa.sh -i
```

#### Opción B: Por línea de comandos (Paso directo sin preguntas)
```bash
./scripts/add-user-2fa.sh -u usuario.desarrollo5 -n "Usuario Desarrollo Cinco" -s "Desarrollo" -o "Desarrollo"
```

El script se encargará de:
1. Validar que no haya colisiones en el LDAP y crear el registro.
2. Forzar la sincronización inmediata en OwnCloud.
3. Crear y registrar el token TOTP en PrivacyIDEA.
4. Mostrar la URL `otpauth://` lista para escanear con FreeOTP o Proton Authenticator.

*(Nota: Los scripts de verificación `ldap-verify.sh`, `privacyidea-verify.sh` y `owncloud-verify.sh` han sido actualizados para soportar nuevos usuarios dinámicos de forma nativa, por lo que no es necesario borrar el usuario después de crearlo; todas las validaciones seguirán en verde y pasando sin problemas).*

### 9. privacyIDEA integrado con LDAP (punto ii)

```bash
./scripts/privacyidea-verify.sh
```

Termina con `Todo OK.` (6 checks).

### 10. Login LDAP + OTP y cifrado en disco (puntos iii y v)

```bash
./scripts/owncloud-login-verify.sh usuario.seguridad2
```

Hace el login web completo de doble factor, sube un archivo y confirma que quedó cifrado. Termina con `OK: archivo subido y cifrado en el volumen.`.

### 11. Mostrar la cabecera de cifrado en disco

```bash
docker exec otpsec-owncloud-server head -c 97 \
  /mnt/data/files/usuario.seguridad2/files/demo-cifrado.txt; echo
```

Debe verse la cabecera de cifrado, no el texto original. La salida completa es:

```
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:signed:true:encoding:binary:HEND
```

Lo que prueba el cifrado es `HBEGIN ... cipher:AES-256-CTR`. El `echo` final solo agrega un salto de línea para que el prompt no quede pegado a la salida.

### 12. Compartir archivo cifrado entre usuarios

```bash
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

`desarrollo3` comparte con `seguridad1`; queda cifrado en disco y el destinatario lo lee en claro. Termina con `OK: usuario.seguridad1 descifró y leyó el archivo compartido.`.

### 13. OwnCloud operando (punto iv, opcional)

```bash
./scripts/owncloud-verify.sh
```

Termina con `Todo OK.` (6 checks).

---

## Bloque 3: Demo en el navegador (login con el teléfono)

Sin comandos. En el navegador, modo incógnito:

1. Ir a `https://localhost:9443`.
2. Aceptar la advertencia de certificado (cert autofirmado de la CA local, esperado).
3. Login: usuario `usuario.desarrollo1` (o `usuario.desarrollo2`), contraseña `sia-user-2026`.
4. En la pantalla de segundo factor, escribir los 6 dígitos de FreeOTP del usuario correspondiente.
5. Entra a la vista de archivos. Sube un archivo arrastrándolo para mostrar que funciona.

Tienes dos usuarios en el teléfono, así que puedes mostrar el login con ambos.

---

## Bloque 4: Apagar al terminar

### 14. Apagar sin borrar datos

```bash
docker compose -f compose/docker-compose.yml --env-file .env down
```

Conserva los volúmenes (datos de LDAP, base de OwnCloud, tokens de privacyIDEA). Mañana basta el paso 2 para volver a levantar. No uses `down -v` salvo que quieras borrar todo y re-enrolar los teléfonos desde cero.

---

## Mapa: comando contra punto evaluable

| Paso | Punto del profesor |
|---|---|
| 8  `ldap-verify.sh` | i. Alta de usuarios en LDAP (verificación) |
| 8b alta con `ldapadd` | i. Alta de usuarios en LDAP (en vivo, si lo pide) |
| 9  `privacyidea-verify.sh` | ii. Integración con privacyIDEA |
| 10 `owncloud-login-verify.sh` | iii. Emisión de OTP y v. doble factor |
| 11 cabecera de cifrado | Cifrar contenido de archivos |
| 12 `owncloud-share-verify.sh` | Compartir archivos entre usuarios |
| 13 `owncloud-verify.sh` | iv. Implementación de OwnCloud |
| Bloque 3 navegador | iii y v en vivo con el teléfono |

---

## Si algo falla

- `wrong otp value` o `RECHAZADO`: el OTP se reusó, el reloj del teléfono está desfasado, o el QR tiene un secreto distinto al de privacyIDEA. Espera al siguiente código y reintenta; si persiste, re-enrola con el bloque del paso 4 o 6 y vuelve a escanear.
- Reloj desfasado: compara `date -u` con `docker exec otpsec-privacyidea date -u`. Si difieren más de 30 segundos, activa la hora automática (NTP) en el teléfono.
- `Connection refused` en privacyIDEA: el contenedor no terminó de arrancar. Espera 20 segundos y reintenta.
- Un contenedor no llega a `healthy`: `docker logs NOMBRE_DEL_CONTENEDOR --tail 30`.
- Reinicio total: `./scripts/bootstrap.sh` completo (sin flags). Tarda más, pero deja todo validado; las pruebas internas usan usuarios alternos.

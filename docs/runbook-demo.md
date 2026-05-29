# Runbook de la demo: lista explícita de comandos

Guía para correr la demo del Proyecto Final de principio a fin, comando por
comando. Pensada para seguirse el día de la presentación sin tener que recordar
nada de memoria.

Regla base: todos los comandos se ejecutan desde la raíz del repositorio.

```bash
cd /Users/jorge/Documents/Escuela/SIA/Proyecto_Final
```

Credenciales que vas a usar:

- Usuarios de demo: `usuario.desarrollo1` ... `usuario.seguridad3`, contraseña `sia-user-2026`.
- El teléfono con FreeOTP se enrola para `usuario.desarrollo1`.
- Los scripts automáticos usan `usuario.desarrollo2`, `usuario.desarrollo3` y `usuario.seguridad1` para no tocar el token del teléfono.

---

## Bloque 0: Arrancar el laboratorio (al llegar al salón)

### Comando 1: arrancar Docker Desktop

```bash
open -a Docker
```

Qué hace: lanza el daemon de Docker. Sin esto, ningún contenedor puede correr.
Espera de 30 a 90 segundos a que el ícono de Docker en la barra de menú deje de
animarse. Para confirmar que el daemon respondió:

```bash
docker info
```

Si imprime información del servidor (no un error de conexión), Docker está listo.

### Comando 2: levantar el stack y confirmar salud

```bash
./scripts/bootstrap.sh --no-build --skip-tests
```

Qué hace: levanta los seis contenedores (reusa las imágenes ya construidas,
por eso `--no-build`), espera a que los seis estén `healthy`, y reaplica la
configuración de PrivacyIDEA y OwnCloud (es idempotente). `--skip-tests` evita
correr la batería de pruebas en este momento, porque esas pruebas las vas a
correr tú en vivo en el Bloque 2. Termina con la palabra `Listo`.

Por qué no `--build`: las imágenes ya están construidas de la primera vez, no
hace falta reconstruir y así arranca en menos de un minuto.

### Comando 3: ver los seis contenedores arriba

```bash
docker compose -f compose/docker-compose.yml --env-file .env ps
```

Qué hace: lista los seis contenedores. Los seis deben decir `Up` y `healthy`:
`otpsec-openldap`, `otpsec-privacyidea`, `otpsec-owncloud-db`,
`otpsec-owncloud-redis`, `otpsec-owncloud-server`, `otpsec-owncloud-proxy`.

---

## Bloque 1: Preparar el teléfono (segundo factor en vivo)

Si ya tienes el token enrolado en FreeOTP de un ensayo anterior y el volumen de
PrivacyIDEA no se borró, puedes saltarte el Comando 4 e ir directo al Comando 6
para confirmar. Si no, empieza en el Comando 4.

### Comando 4: enrolar el token y generar el QR (en un solo bloque)

Importante: enrola y genera el QR en el MISMO bloque. El secreto que queda en
PrivacyIDEA y el secreto dentro del QR deben ser el mismo; este bloque lo
garantiza porque el QR se arma con la URL del enrolamiento que acaba de correr.

```bash
URL=$(./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo1 2>&1 | grep -oE 'otpauth://[^ ]+' | head -1)
echo "URL activa: $URL"
qrencode -o /tmp/otp-qr.png -s 10 "$URL"
open /tmp/otp-qr.png
```

Qué hace: enrola un token TOTP nuevo para `usuario.desarrollo1` (PrivacyIDEA
genera la semilla con `genkey=1` y borra cualquier token previo), captura la URL
`otpauth://` de esa misma corrida, la convierte en un PNG con el QR y lo abre en
Vista Previa.

Trampa a evitar: no pegues por separado una URL ni un secreto de otra corrida.
Si el QR trae un secreto distinto al que quedó en PrivacyIDEA, la validación
falla con `wrong otp value`. Corre solo este bloque, de una vez.

### Comando 5: escanear el QR con FreeOTP

No es un comando de terminal. En el teléfono:

1. Si ya habías escaneado un token `TOTP_usuario_desarrollo1` antes, bórralo de
   FreeOTP primero para no confundir un código viejo con el nuevo.
2. Abre FreeOTP, toca el botón "+" o el icono de cámara.
3. Apunta al QR abierto en Vista Previa. FreeOTP crea la entrada
   `TOTP_usuario_desarrollo1` y muestra un código de seis dígitos que cambia
   cada 30 segundos.

### Comando 6: confirmar que el teléfono está sincronizado

```bash
./scripts/privacyidea-validate-otp.sh usuario.desarrollo1 CODIGO_DE_6_DIGITOS
```

Reemplaza `CODIGO_DE_6_DIGITOS` por el número que muestra FreeOTP en ese momento.
Qué hace: envía ese código a PrivacyIDEA. Debe responder `OK: PrivacyIDEA aceptó
el OTP.`. Si dice `RECHAZADO`, el reloj del teléfono está desfasado: actívale la
hora automática (NTP) y reintenta con el siguiente código.

---

## Bloque 2: Demo en la terminal (los cinco puntos que evalúa el profesor)

Cada comando imprime su resultado en pantalla. Pausa unos segundos tras cada
`OK` o `Todo OK` para que el grupo lo lea.

### Comando 7: usuarios dados de alta en LDAP (punto i)

```bash
./scripts/ldap-verify.sh
```

Qué demuestra: que el directorio LDAP tiene las dos unidades organizacionales
(Desarrollo y Seguridad) con tres usuarios cada una, que la cuenta de servicio
puede leerlos, que una contraseña incorrecta se rechaza, y que LDAPS funciona
con el certificado de la CA del proyecto. Termina con `Todo OK.` (ocho checks).

### Comando 8: PrivacyIDEA integrado con LDAP (punto ii)

```bash
./scripts/privacyidea-verify.sh
```

Qué demuestra: que PrivacyIDEA usa el LDAP como resolver por LDAPS, que el realm
`sia` existe, y que resuelve exactamente los seis usuarios. PrivacyIDEA no tiene
usuarios propios: los lee de LDAP. Termina con `Todo OK.` (seis checks).

### Comando 9: login con LDAP mas OTP y cifrado en disco (puntos iii y v)

```bash
./scripts/owncloud-login-verify.sh usuario.desarrollo2
```

Qué demuestra: el flujo completo de doble factor contra OwnCloud. Hace el primer
factor (usuario y contraseña contra LDAP), genera un OTP de prueba, lo envía al
plugin `twofactor_privacyidea`, OwnCloud abre la sesión, sube un archivo y
confirma que en disco quedó cifrado. Termina con
`OK: archivo subido y cifrado en el volumen.`.

### Comando 10: mostrar la cabecera de cifrado en disco

```bash
docker exec otpsec-owncloud-server head -c 80 \
  /mnt/data/files/usuario.desarrollo2/files/demo-cifrado.txt
```

Qué demuestra: lee los primeros 80 bytes del archivo que subió el Comando 9,
directamente del volumen del servidor. Debe verse la cabecera de cifrado, no el
texto original:

```
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

Si vieras el texto legible, el cifrado no estaría activo. Esto prueba el
requisito de cifrar el contenido de los archivos.

### Comando 11: compartir un archivo cifrado entre usuarios

```bash
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

Qué demuestra: `usuario.desarrollo3` sube un archivo, lo comparte con
`usuario.seguridad1`, el archivo queda cifrado en disco, y el destinatario lo
descarga y lo lee en claro. Termina con
`OK: usuario.seguridad1 descifró y leyó el archivo compartido.`.

### Comando 12 (opcional): OwnCloud operando (punto iv)

```bash
./scripts/owncloud-verify.sh
```

Qué demuestra: que OwnCloud responde por HTTPS, está instalado, tiene el backend
LDAP activo, el plugin 2FA y el cifrado del lado servidor. Termina con
`Todo OK.` (seis checks). El punto iv (OwnCloud implementado) ya queda implícito
en los comandos 9 a 11, este es el cierre formal si el profesor lo pide.

---

## Bloque 3: Demo en el navegador (el segundo factor con el teléfono)

Esto es lo más vistoso: el login real con tu teléfono. No hay comandos de
terminal, son pasos en el navegador.

1. Abre el navegador en modo incógnito.
2. Entra a `https://localhost:9443`.
3. Acepta la advertencia de certificado (es el certificado autofirmado de la CA
   local, esperado en un laboratorio).
4. Login con usuario `usuario.desarrollo1` y contraseña `sia-user-2026`.
5. OwnCloud redirige a la pantalla de segundo factor (`/login/selectchallenge`).
6. Escribe el código de seis dígitos que muestra FreeOTP en ese momento.
7. La sesión abre en la vista de archivos (`/apps/files/`).
8. Sube un archivo arrastrándolo a la ventana para mostrar que funciona.

Consejo: deja FreeOTP abierto en pantalla para que el grupo vea el contador de
30 segundos bajando.

---

## Bloque 4: Apagar al terminar

### Comando 13: apagar sin borrar datos

```bash
docker compose -f compose/docker-compose.yml --env-file .env down
```

Qué hace: detiene y elimina los contenedores, pero conserva los volúmenes (los
datos de LDAP, la base de OwnCloud, el token de PrivacyIDEA). La próxima vez
basta el Comando 2 para volver a levantar todo.

No corras `down -v` salvo que quieras borrar todos los datos y empezar de cero,
porque eso elimina el token enrolado y obliga a repetir el Bloque 1.

---

## Mapa rápido: comando contra punto evaluable

| Comando | Punto del profesor |
|---|---|
| 7  `ldap-verify.sh` | i. Alta de usuarios en LDAP |
| 8  `privacyidea-verify.sh` | ii. Integración con PrivacyIDEA |
| 9  `owncloud-login-verify.sh` | iii. Emisión de OTP y v. doble factor |
| 10 `head -c` cabecera de cifrado | Cifrar contenido de archivos |
| 11 `owncloud-share-verify.sh` | Compartir archivos entre usuarios |
| 12 `owncloud-verify.sh` | iv. Implementación de OwnCloud |
| Bloque 3 navegador | iii y v en vivo con el teléfono |

---

## Si algo falla

- `Connection refused` en PrivacyIDEA: el contenedor no terminó de arrancar.
  Espera 20 segundos y reintenta.
- `wrong otp value` o `RECHAZADO`: el OTP se reusó o el reloj del teléfono está
  desfasado. Espera al siguiente código de FreeOTP y reintenta.
- Un contenedor no llega a `healthy`: revisa sus logs con
  `docker logs NOMBRE_DEL_CONTENEDOR --tail 30`.
- Caso extremo: vuelve a correr `./scripts/bootstrap.sh` completo (sin flags).
  Tarda más porque reconstruye, pero deja todo validado. Las pruebas internas
  usan usuarios alternos, no tocan el token del teléfono.

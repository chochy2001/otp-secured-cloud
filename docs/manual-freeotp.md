# Manual del equipo: enrolar el TOTP demo en FreeOTP o Proton Authenticator

Antes de la exposición, al menos un integrante debe tener un teléfono real con una app TOTP lista para mostrar el segundo factor en vivo. FreeOTP y Proton Authenticator funcionan con la URL `otpauth://` que genera privacyIDEA. Este documento describe el procedimiento completo.

## Requisitos previos

1. Tener el stack levantado y verificado:
   ```bash
   ./scripts/bootstrap.sh
   ```
   Ejecuta este comando antes de enrolar el teléfono. Las pruebas automáticas usan usuarios alternos para no reemplazar el token físico de `usuario.desarrollo1`.
2. Un teléfono Android o iOS con FreeOTP o Proton Authenticator instalada:
   - Android: Google Play, búsqueda "FreeOTP" (autor Red Hat). Repositorio del proyecto: https://github.com/freeotp/freeotp-android
   - iOS: App Store, búsqueda "FreeOTP". Repositorio: https://github.com/freeotp/freeotp-ios
   - Proton Authenticator: escanea el mismo QR y muestra un código TOTP de 6 dígitos cada 30 segundos.
3. Una herramienta para generar códigos QR a partir de la URL `otpauth://`. Opciones:
   - Línea de comandos: `qrencode` (en macOS: `brew install qrencode`; en Debian/Ubuntu: `sudo apt install qrencode`).
   - Generador en línea: NO recomendado para uso real porque la URL contiene el secreto del token. Para fines académicos se acepta como respaldo, pero el equipo debe entender el riesgo.

## Procedimiento

### 1. Generar el token TOTP en privacyIDEA

Elige el usuario que se va a usar en la demo (el guion sugiere `usuario.desarrollo1`). Ejecuta:

```bash
./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo1
```

Este comando reemplaza cualquier token anterior de `usuario.desarrollo1`. Úsalo solo para el primer enrolamiento del teléfono o cuando quieras rotar intencionalmente el QR de la demo.

El script:
- Borra cualquier token previo del mismo usuario para evitar conflictos.
- Crea un token TOTP nuevo con `genkey=1` (privacyIDEA genera la semilla).
- Imprime una URL `otpauth://totp/...?secret=...&period=30&digits=6&issuer=privacyIDEA`.
- Verifica que el token funciona calculando un OTP local con Python y validándolo contra `/validate/check`.

Copia la URL `otpauth://...` impresa al final.

### 2. Convertir la URL a un QR

Con `qrencode` instalado:

```bash
echo "otpauth://totp/...?secret=...&period=30&digits=6&issuer=privacyIDEA" | qrencode -t ANSIUTF8
```

`-t ANSIUTF8` imprime el QR directamente en la terminal con caracteres Unicode. El QR puede escanearse desde el monitor sin imprimir nada.

Alternativa que genera un PNG escalable:

```bash
echo "otpauth://totp/...?secret=...&period=30&digits=6&issuer=privacyIDEA" | qrencode -o /tmp/qr.png -s 8
open /tmp/qr.png   # macOS
xdg-open /tmp/qr.png   # Linux
```

### 3. Escanear con FreeOTP o Proton Authenticator

1. Abre FreeOTP o Proton Authenticator en el teléfono.
2. Toca el botón "+" o el icono de cámara para agregar un nuevo token.
3. Apunta la cámara al QR. La app detecta la URL `otpauth://`, extrae el secreto y crea una entrada con etiqueta `TOTP_usuario_desarrollo1` (o el serial que privacyIDEA haya asignado).
4. Inmediatamente la app muestra un código de 6 dígitos que se renueva cada 30 segundos.

### 4. Validar el primer código en vivo

Antes de cerrar el procedimiento, valida que el código generado por el teléfono también es aceptado por privacyIDEA:

```bash
./scripts/privacyidea-validate-otp.sh usuario.desarrollo1 <codigo-de-6-digitos-del-telefono>
```

La salida `OK: la validación fue exitosa` confirma que el dispositivo y el servidor están sincronizados. Si falla con "wrong otp value", probablemente el reloj del teléfono difiere del servidor. En la mayoría de los casos los teléfonos sincronizan vía NTP automáticamente; si no, ajusta la fecha y hora manualmente.

### 5. Probar el login web completo

Con el código actual del teléfono:

1. Abre `https://localhost:9443` en un navegador limpio (modo incógnito).
2. Acepta la advertencia de certificado autofirmado.
3. Login con:
   - Usuario: `usuario.desarrollo1`
   - Contraseña: `sia-user-2026`
4. Cuando OwnCloud redirija a `/login/selectchallenge`, ingresa el OTP de 6 dígitos visible en la app TOTP.
5. La sesión debe abrir en `/apps/files/` y mostrar la carpeta personal del usuario.

Listo: el segundo factor con un dispositivo real está validado.

## Consejos para la demo en vivo

- **Separar demo y pruebas automáticas**: usa `usuario.desarrollo1` para el teléfono real, y deja que los scripts automáticos trabajen con `usuario.desarrollo2`, `usuario.desarrollo3` y `usuario.seguridad1`.
- **No cierres la app**: mantén FreeOTP o Proton Authenticator abierta en pantalla durante la demo para que el público vea el contador descender de 30 a 0 segundos.
- **Brillo alto y modo claro**: facilita la lectura del código a los que están al fondo del salón.
- **Modo no-molestar**: silencia notificaciones del teléfono. Una llamada o un mensaje cubriendo la pantalla rompe el momento.
- **Practica con el código exacto**: en el ensayo, escribe los 6 dígitos sin verificar dos veces. Practica el ritmo entre leer y teclear.

## Limpieza después de la presentación

Si el teléfono que usaste es personal y no quieres dejar el token enrolado:

1. En FreeOTP o Proton Authenticator, elimina la entrada del token desde la app.
2. En privacyIDEA, ejecuta:
   ```bash
   ADMIN_TOKEN=$(curl --cacert ./certs/ca.crt -s -X POST https://localhost:8443/auth \
     --data-urlencode "username=admin" --data-urlencode "password=sia-pi-admin-2026" \
     | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['value']['token'])")
   curl --cacert ./certs/ca.crt -X DELETE \
     -H "Authorization: $ADMIN_TOKEN" \
     "https://localhost:8443/token/TOTP_usuario_desarrollo1"
   ```

Esto invalida la semilla compartida; ningún código generado por la app servirá ya. Si vuelves a enrolar, se generan secreto y QR nuevos.

## Solución a problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| La app muestra "Cannot decode QR code" | El QR está borroso o el escáner no enfoca | Aumenta el zoom de la imagen, mejora la iluminación, o usa entrada manual del secreto |
| El OTP del teléfono se rechaza siempre | Reloj del teléfono fuera de sincronía | Ajusta hora del teléfono a "automática" (NTP) o sincroniza manualmente |
| `privacyidea-validate-otp.sh` falla con "wrong otp value. previous otp used again" | Reusaste un OTP antes de que cambiara la ventana | Espera 30 segundos para que el código se renueve antes de validar |
| OwnCloud muestra `Internal Server Error` después del OTP | Se intentó usar el token de `usuario.desarrollo1` mientras la sesión del navegador estaba como `admin` u otro usuario | Cierra sesión, abre modo incógnito y entra con `usuario.desarrollo1` / `sia-user-2026`; el token solo sirve para el usuario al que fue enrolado |
| El navegador rechaza el certificado de OwnCloud sin opción de continuar | El cliente no confía en la CA local | Importa `certs/ca.crt` al keychain/almacén de certificados del sistema operativo, o acepta la excepción manualmente |
| La app TOTP no puede escanear el QR | iOS o Android bloqueó el acceso a la cámara | Habilita permisos de cámara para FreeOTP o Proton Authenticator |

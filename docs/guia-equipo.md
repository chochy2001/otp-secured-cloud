# Guía para el equipo: cómo levantar el proyecto

Esta guía describe el procedimiento paso a paso para clonar el repositorio, levantar el entorno y verificar que todo funciona en tu máquina. Está pensada para que cualquiera del equipo (y cualquier evaluador del curso) pueda reproducir el entorno sin depender de otra persona.

## 1. Requisitos previos

Antes de empezar necesitas tener instalado:

| Herramienta | Versión recomendada | Para qué |
|---|---|---|
| Docker Desktop (Mac/Windows) o Docker Engine (Linux) | 24.0 o superior | Correr los contenedores |
| Docker Compose | v2.x (viene con Docker Desktop) | Orquestar varios servicios |
| Git | 2.30 o superior | Clonar el repositorio |
| Bash | 3.2 o superior | Correr los scripts del proyecto |
| Python 3, curl y OpenSSL | Versiones del sistema | Calcular TOTP, probar HTTPS y generar certificados |

En macOS, `bash` viene en versión 3.2 por compatibilidad histórica, pero el script de verificación funciona también con esa versión. Si tienes una más nueva instalada vía Homebrew, mejor.

Verifica que Docker esté corriendo:

```bash
docker info
```

Si da error de socket, abre Docker Desktop y espera a que termine de iniciar antes de seguir.

## 2. Clonar el repositorio

```bash
git clone https://github.com/chochy2001/otp-secured-cloud.git
cd otp-secured-cloud
```

## 3. Revisar las contraseñas del entorno

El archivo `.env` viene incluido a propósito con las credenciales académicas del proyecto. Úsalas tal cual para desarrollo. **No repliques esta práctica en un proyecto real.**

Las credenciales siguen el patrón `sia-<rol>-2026`:

| Uso | Valor |
|---|---|
| Admin del LDAP (`cn=admin,dc=sia,dc=unam,dc=mx`) | `sia-admin-2026` |
| Admin de la configuración LDAP (`cn=admin,cn=config`) | `sia-config-2026` |
| Cuenta de servicio (`cn=svc-owncloud,ou=Servicios`) | `sia-svc-2026` |
| Cualquiera de los 6 usuarios de prueba | `sia-user-2026` |
| Admin de PrivacyIDEA | `sia-pi-admin-2026` |
| Admin de OwnCloud | `sia-oc-admin-2026` |

## 4. Levantar y validar el stack

Desde la raíz del repositorio:

```bash
./scripts/bootstrap.sh
```

El primer arranque puede tardar varios minutos porque descarga imágenes y construye PrivacyIDEA. Los siguientes son más rápidos. El script genera certificados, levanta Docker Compose, configura privacyIDEA y OwnCloud, y ejecuta la batería completa de pruebas.

Para ver los logs del contenedor mientras arranca:

```bash
docker compose -f compose/docker-compose.yml --env-file .env logs -f
```

Ctrl-C para salir del `tail` (el contenedor sigue corriendo).

## 5. Configurar y verificar

El flujo normal no necesita comandos adicionales: `./scripts/bootstrap.sh` ya configura y verifica todo. Si quieres repetir solo las pruebas con el stack ya levantado:

```bash
./scripts/ldap-verify.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo2
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

`usuario.desarrollo1` se reserva para la demo visual con el teléfono. Las pruebas automáticas generan tokens TOTP nuevos, por eso usan usuarios alternos.

Opcional (complemento académico, el profesor confirmó que la auditoría no se evalúa):

```bash
./scripts/bootstrap.sh --with-audit
```

Deberías ver:

1. LDAP con 6 usuarios humanos y LDAPS validado.
2. PrivacyIDEA con resolver `sia-ldap`, realm `sia` y 6 usuarios.
3. Token TOTP reproducible validado contra la API.
4. OwnCloud en `https://localhost:9443`, LDAP por LDAPS, 2FA activo y cifrado del lado servidor.
5. Login web real con usuario LDAP + OTP, subida WebDAV y archivo cifrado en disco.
6. Archivo compartido por OCS Sharing API, descargado descifrado por el destinatario.

Si además se ejecuta el script opcional `audit-capture.sh`, se obtiene como salida adicional `docs/auditoria.md` con extractos reales de los 8 eventos clave. Esa salida es complemento académico y no es parte de la cadena de validación principal.

Si alguno de los pasos falla, revisa la sección [Problemas comunes](#7-problemas-comunes) más abajo. Para una guía exhaustiva del día de la presentación, ver [`como-probar.md`](como-probar.md).

## 6. Pruebas manuales útiles

### Validar el primer factor desde la terminal (login de usuario)

Simular lo que hará OwnCloud al autenticar al usuario:

```bash
docker exec -it otpsec-openldap ldapwhoami -x \
  -H ldap://localhost \
  -D "uid=usuario.desarrollo1,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" \
  -w "sia-user-2026"
```

Debe responder con `dn:uid=usuario.desarrollo1,...`.

### Probar que una contraseña incorrecta se rechaza

```bash
docker exec -it otpsec-openldap ldapwhoami -x \
  -H ldap://localhost \
  -D "uid=usuario.desarrollo1,ou=Desarrollo,ou=Usuarios,dc=sia,dc=unam,dc=mx" \
  -w "contrasena-incorrecta"
```

Debe responder `ldap_bind: Invalid credentials (49)`. Ese error es importante para la capa de **auditoría**: aparecerá también en los logs del contenedor.

### Consultar manualmente todo el árbol

```bash
docker exec -it otpsec-openldap ldapsearch -x \
  -H ldap://localhost \
  -b "dc=sia,dc=unam,dc=mx" \
  -D "cn=admin,dc=sia,dc=unam,dc=mx" \
  -w "sia-admin-2026"
```

## 7. Problemas comunes

### El puerto 389, 6636, 8443 o 9443 ya está en uso

Revisa qué contenedor o proceso lo ocupa:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
lsof -nP -iTCP -sTCP:LISTEN | grep -E '389|6636|8443|9443'
```

Si es un contenedor de otro proyecto, detén ese contenedor o cambia temporalmente el puerto publicado en `compose/docker-compose.yml`.

### Cambié un LDIF y mi cambio no aparece en el directorio

Osixia solo ejecuta los LDIFs de `ldap/bootstrap/` **una vez**, en el primer arranque sobre volúmenes vacíos. Si ya había corrido el contenedor antes, los LDIFs posteriores se ignoran. Para forzar la reimportación:

```bash
docker compose -f compose/docker-compose.yml --env-file .env down -v
./scripts/bootstrap.sh
```

Atención: esto borra todos los datos actuales del LDAP. En desarrollo no importa; en producción sería catastrófico.

### `docker info` da error de socket

Docker Desktop no está corriendo. Ábrelo desde Aplicaciones (macOS) o con `systemctl --user start docker-desktop` (Linux), espera unos segundos y reintenta.

### El script `ldap-verify.sh` se queja de variables indefinidas

Asegúrate de que el archivo `.env` está en la raíz del repo. El script lo carga con `source $ROOT_DIR/.env`. Si acabas de clonar no debería ser necesario crearlo: viene incluido en el repo.

### Cambié `.env` pero los contenedores siguen con las contraseñas viejas

Docker Compose pasa las variables al momento de crear el contenedor. Si cambias `.env` después, tienes que recrear:

```bash
docker compose -f compose/docker-compose.yml --env-file .env down
./scripts/bootstrap.sh
```

Y si además cambiaste contraseñas usadas en los LDIFs, necesitas además `down -v` para que el LDAP las recargue desde cero.

## 8. Apagar el entorno

```bash
docker compose -f compose/docker-compose.yml --env-file .env down
# ó:
docker compose -f compose/docker-compose.yml --env-file .env down -v
```

## 9. Generar artefactos de entrega

Cuando se prepare la entrega final, además del entorno operativo se necesitan dos artefactos derivados:

```bash
# Renderizar las 6 figuras Mermaid a PNG (requiere npm)
npm install -g @mermaid-js/mermaid-cli
./scripts/build-figures.sh

# Ensamblar el PDF del entregable (requiere pandoc + LaTeX)
brew install pandoc tectonic          # macOS (tectonic no requiere sudo)
# o: sudo apt install pandoc texlive-xetex   # Linux
./scripts/build-pdf.sh
```

El PDF queda en `build/entregable-otp-secured-cloud.pdf` y las figuras en `docs/figuras/figuraN.png`. Ambos están en `.gitignore`: cada integrante los regenera localmente cuando los necesita.

## 10. Documentos siguientes

Para profundizar en un área específica:

- [`como-probar.md`](como-probar.md): guía operativa para el día de la presentación, incluye pre-flight checklist y plan B.
- [`continuidad.md`](continuidad.md): estado consolidado, pendientes reales y mejoras futuras fuera del alcance.
- [`guion-exposicion.md`](guion-exposicion.md): bloques por integrante para los 30 minutos de exposición.
- [`presentacion.md`](presentacion.md): slides en formato Marp listas para abrir con la extensión correspondiente.
- [`manual-freeotp.md`](manual-freeotp.md): cómo enrolar el TOTP demo en un teléfono real.
- [`auditoria.md`](auditoria.md): extractos reales de los logs de los 8 eventos clave.
- [`memoria-tecnica.md`](memoria-tecnica.md): recorrido detallado de la implementación por fases.

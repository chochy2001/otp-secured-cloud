# Cómo probar el proyecto antes y durante la presentación

Esta guía es la lista de verificación operativa para el día de la entrega. Cubre desde la instalación de prerrequisitos hasta la batería de pruebas a correr durante la demo. Está pensada para que cualquier integrante pueda seguirla sin tener que recordar comandos de memoria.

## 1. Prerrequisitos en la laptop de la demo

Software que tiene que estar instalado antes de bajar el repo:

| Herramienta | Para qué se usa | Instalación rápida (macOS) | Instalación rápida (Ubuntu/Debian) |
|---|---|---|---|
| Docker Desktop o Docker Engine + Compose v2 | Levantar el stack | https://www.docker.com/products/docker-desktop | `sudo apt install docker.io docker-compose-plugin` |
| `git` | Clonar el repo | preinstalado o `brew install git` | `sudo apt install git` |
| `python3` | Cálculos TOTP en los scripts | preinstalado | `sudo apt install python3` |
| `curl` | Pruebas HTTP/HTTPS | preinstalado | preinstalado |
| `openssl` | Generación de la CA local | preinstalado | preinstalado |
| `shellcheck` (opcional) | Lint de scripts shell | `brew install shellcheck` | `sudo apt install shellcheck` |
| `node` y `npm` (opcional) | Renderizar figuras Mermaid | `brew install node` | `sudo apt install nodejs npm` |
| `pandoc` y motor LaTeX (opcional) | Generar el PDF del entregable | `brew install pandoc tectonic` | `sudo apt install pandoc texlive-xetex` |
| `mermaid-cli` (opcional) | Convertir bloques Mermaid a PNG | `npm install -g @mermaid-js/mermaid-cli` | igual |

Las cuatro últimas filas son opcionales: solo se necesitan si se va a generar el PDF del entregable o las figuras renderizadas el mismo día. Para la demo en vivo bastan Docker y los scripts ya versionados.

## 2. Clonar y levantar el stack

```bash
git clone git@github.com:chochy2001/otp-secured-cloud.git
cd otp-secured-cloud
./scripts/bootstrap.sh
```

El script genera certificados, levanta Docker Compose, espera a que los seis contenedores queden `healthy`, configura privacyIDEA y OwnCloud, y corre la batería completa de pruebas. Si termina con `Listo`, el laboratorio quedó funcional para la demo.

Para la demo web usa siempre un usuario LDAP, por ejemplo `usuario.desarrollo1` con contraseña `sia-user-2026`. La cuenta `admin` es solo de mantenimiento local de OwnCloud y queda excluida del segundo factor porque no existe en el realm LDAP `sia` de privacyIDEA.

Confirmación visual opcional:

```bash
docker compose -f compose/docker-compose.yml --env-file .env ps
```

Los seis contenedores deben estar `Up` y `healthy`:

```
otpsec-openldap          Up (healthy)
otpsec-privacyidea       Up (healthy)
otpsec-owncloud-db       Up (healthy)
otpsec-owncloud-redis    Up (healthy)
otpsec-owncloud-server   Up (healthy)
otpsec-owncloud-proxy    Up (healthy)
```

Si un servicio tarda, `bootstrap.sh` espera hasta 7 minutos y muestra logs si algo no llega a `healthy`.

## 3. Configurar privacyIDEA y OwnCloud

El flujo normal no requiere configurar nada a mano: `./scripts/bootstrap.sh` ejecuta estos dos scripts internamente.

```bash
./scripts/privacyidea-configure.sh
./scripts/owncloud-configure.sh
```

Se mantienen como comandos de diagnóstico cuando se quiere reconfigurar solo una capa. Cada uno termina con `Configuración completa` o equivalente y es idempotente.

## 4. Batería de validación completa

`./scripts/bootstrap.sh` ya ejecuta esta cadena. Si el entorno ya está levantado y solo se quiere repetir la validación sin reconstruir contenedores, correr:

```bash
./scripts/ldap-verify.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo1
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
```

Salidas esperadas:

| Script | Termina con | Qué cierra |
|---|---|---|
| `ldap-verify.sh` | `Todo OK.` (8 checks) | Validación i del profesor |
| `privacyidea-verify.sh` | `Todo OK.` (6 checks) | Validación ii |
| `owncloud-verify.sh` | `Todo OK.` (6 checks) | Validación iv |
| `owncloud-login-verify.sh` | `OK: archivo subido y cifrado en el volumen.` | Validaciones iii y v |
| `owncloud-share-verify.sh` | `OK: <destinatario> descifró y leyó el archivo compartido.` | Cifrado de archivos compartidos |

Cualquier fallo aborta el script con `ERROR:` y un código distinto de 0. La regla es: ningún `ERROR:` en la salida = todo verde.

Complemento opcional (auditoría, el profesor confirmó que no se evalúa):

```bash
./scripts/bootstrap.sh --with-audit
# o solo la auditoría, si el stack ya está arriba:
./scripts/audit-capture.sh
```

Solo se corre si el equipo quiere bitácoras frescas o si el profesor pregunta por evidencia de logs durante la sesión.

## 5. Verificación visual en navegador

Antes de la presentación, abrir `https://localhost:9443` en una pestaña de incógnito y comprobar:

1. El navegador muestra la advertencia de certificado (esperado: cert autofirmado de la CA local). Continuar y aceptar la excepción una vez.
2. Login con `usuario.desarrollo1` y password `sia-user-2026`. Debe redirigir a `/login/selectchallenge`.
3. Ingresar el OTP de 6 dígitos visible en FreeOTP o calculado por `scripts/privacyidea-enroll-test-token.sh usuario.desarrollo1`. Debe abrir la vista de archivos en `/apps/files/`.
4. Subir un archivo desde la UI (drag-and-drop). Confirmar que aparece listado.
5. Cerrar sesión.

La pestaña abierta y autenticada se puede dejar lista para que la demo sea más rápida.

## 6. Verificación de cifrado en disco

Demostración importante para el bloque de cifrado:

```bash
docker exec otpsec-owncloud-server head -c 80 \
  /mnt/data/files/usuario.desarrollo1/files/demo-cifrado.txt
```

Salida (los primeros 80 bytes):

```
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

Si en cambio se ve el texto `sia-demo-confidencial-...`, el cifrado NO está activo: revisar `./scripts/owncloud-verify.sh`.

## 7. Pre-flight checklist (24 h antes)

Lista a ejecutar el día anterior a la presentación, en la laptop que se usará en vivo:

```bash
git pull origin main
./scripts/bootstrap.sh
```

Verificaciones de presentación:

- `docker compose -f compose/docker-compose.yml --env-file .env ps` muestra los 6 contenedores `Up` y `healthy`.
- El navegador en modo incógnito tiene aceptada la excepción del cert de `https://localhost:9443`.
- El teléfono con FreeOTP tiene un token enrolado para el usuario demo (ver `docs/manual-freeotp.md`).
- Si se va a presentar el PDF: `./scripts/build-figures.sh` y `./scripts/build-pdf.sh` ejecutados con éxito.
- El teléfono de la demo tiene batería suficiente.

Solo si se va a mostrar auditoría durante la sesión (el profesor confirmó que esa capa no se evalúa, así que normalmente se omite):

- `./scripts/audit-capture.sh` ejecutado y `docs/auditoria.md` regenerado con sus 8 secciones.

## 8. Día de la presentación

Llegar al salón 20 minutos antes. Pasos:

1. Encender la laptop, conectar al proyector, ajustar resolución.
2. Abrir tres terminales en pestañas separadas:
   - Pestaña 1: raíz del repo, lista para correr scripts.
   - Pestaña 2: `docker compose -f compose/docker-compose.yml --env-file .env logs -f` (no usar en vivo, solo por si algo falla).
   - Pestaña 3: para el comando `head -c 80` que demuestra cifrado en disco.
3. Abrir el navegador en modo incógnito. Cargar `https://localhost:9443/login` y aceptar el cert de la CA local.
4. Confirmar el estado del entorno antes de enrolar el teléfono físico:
   ```bash
   ./scripts/bootstrap.sh --no-build
   ```
   Debe terminar con `Listo`.
5. Enrolar o confirmar el token de FreeOTP para el usuario demo. Las pruebas automáticas rotan tokens de prueba, por eso este paso va después de `bootstrap.sh`.
6. Abrir `docs/presentacion.md` en Marp (VS Code con extensión Marp, o `marp --pdf docs/presentacion.md`) o cargar el PDF generado.
7. Si solo se quiere revisar salud sin volver a tocar tokens:
   ```bash
   ./scripts/bootstrap.sh --no-build --skip-tests
   ```

## 9. Demo en vivo (orden ensayado)

Bloque 5 del guion (`docs/guion-exposicion.md`). Salgado/Esteban (presentador) ejecuta los siguientes comandos en orden:

```bash
# 1. Login con LDAP + OTP, archivo cifrado en disco
./scripts/owncloud-login-verify.sh usuario.desarrollo1

# 2. Compartir archivo entre usuarios
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1

# 3. Mostrar la cabecera de cifrado
docker exec otpsec-owncloud-server head -c 80 \
  /mnt/data/files/usuario.desarrollo1/files/demo-cifrado.txt
echo

# 4. Auditoría reproducible (opcional, solo si el profesor pregunta)
# El profesor confirmó por correo que esta capa no será evaluada.
# Mantener listo por si surge la pregunta durante la sesión.
./scripts/audit-capture.sh

# 5. Si se decide mostrar la auditoría, abrir tres ejemplos del archivo
sed -n '36,45p' docs/auditoria.md   # login LDAP fallido
sed -n '110,127p' docs/auditoria.md # login web 2FA exitoso
sed -n '129,146p' docs/auditoria.md # login web con OTP rechazado
```

Cada comando produce salida visible al público. Pausar 5 segundos después de cada `OK:` para que se lea. La parte de auditoría (puntos 4 y 5) se ejecuta solo si surge la pregunta del profesor; el bloque principal de la demo termina en el punto 3.

## 10. Plan B si la demo falla

| Síntoma | Causa probable | Plan B |
|---|---|---|
| `Connection refused` en privacyIDEA | El contenedor no terminó de arrancar | Esperar 20 s y reintentar el script |
| `wrong otp value. previous otp used again` | El OTP se reutilizó en la misma ventana de 30 s | Esperar al siguiente cambio de OTP en FreeOTP |
| `401 Unauthorized` en WebDAV | Sesión 2FA expiró | Reejecutar el script desde el principio (es idempotente) |
| Caddy no responde en `:9443` | Conflicto de puertos en el host | `docker compose -f compose/docker-compose.yml --env-file .env ps` y `lsof -i:9443` para diagnosticar |
| Docker no levanta | Memoria insuficiente | Aumentar recursos en Docker Desktop o reiniciar la VM |
| Internet no conecta en el salón | No es necesario en vivo | El stack es local, no afecta |

Si el entorno falla por completo:

- Reproducir la grabación de respaldo de la demo (sugerencia: grabar con `asciinema rec` los pasos del bloque 9 antes del día de la entrega).
- Mostrar capturas de pantalla en el deck con los `OK:` finales de cada script.

## 11. Después de la presentación

Para que el laboratorio quede limpio en la laptop sin perder el código:

```bash
# Apagar contenedores manteniendo volúmenes
docker compose -f compose/docker-compose.yml --env-file .env down

# Si se quiere borrar todo y empezar desde cero
docker compose -f compose/docker-compose.yml --env-file .env down -v
docker builder prune -a -f
```

NO ejecutar `docker volume prune` global sin antes ver `docker volume ls` y `docker volume inspect`: hay otros proyectos del usuario en la misma máquina.

## 12. Resolución de problemas frecuentes

### "Cannot connect to OpenLDAP"

OpenLDAP necesita 10 a 30 segundos para inicializar la primera vez. Esperar y reintentar.

```bash
docker logs otpsec-openldap --tail 20
```

Buscar líneas como `slapd starting` y `slapd starting on port 389`. Cuando aparezcan, el servicio está listo.

### "wrong otp value"

Causa común: el reloj del teléfono está fuera de sincronía con el servidor.

```bash
date -u   # hora UTC del host
docker exec otpsec-privacyidea date -u   # hora UTC del contenedor
```

Si difieren más de 30 segundos, ajustar el reloj del teléfono o del host. Habilitar NTP automático en ambos.

### "Login failed: 'usuario.desarrolloN'" en el log

Suele ser un intento de Basic Auth contra OwnCloud, NO un fallo de password. OwnCloud rechaza Basic Auth cuando 2FA está habilitado y registra "Login failed". El flujo correcto pasa por las cookies de sesión web. Los scripts del proyecto ya lo manejan así.

### Contenedor en estado `Restarting`

```bash
docker compose -f compose/docker-compose.yml --env-file .env logs <servicio>
```

Buscar la última línea de error. Causas comunes: certificado expirado (regenerar con `./scripts/generate-certs.sh --force`), volumen corrupto (borrar con `down -v`), variable de entorno faltante (revisar `.env`).

## 13. Contactos del equipo

| Integrante | Correo | Rol en la presentación |
|---|---|---|
| Arellanes Conde Esteban | esteban.arellanes@ingenieria.unam.edu | Demo en vivo |
| Ferreira Rojas Mauricio | mauferreira183@gmail.com | privacyIDEA y FreeOTP |
| López Segundo Luis Iván | lopezsknd@gmail.com | Diseño del árbol LDAP |
| Olvera González Arely | arely.olvera@ingenieria.unam.edu | Marco conceptual 2FA y OTP |
| Rufino López María Elena | mariaelena.rufino424@gmail.com | OwnCloud y orquestación 2FA |
| Salgado Miranda Jorge | ohchochy@gmail.com | Apertura, conclusiones, propietario del repo |

Si una persona no llega: el guion permite redistribuir bloques sin perder coherencia. El que cubra debe haber leído al menos el archivo de su nuevo bloque la noche anterior.

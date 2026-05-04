---
marp: true
theme: default
paginate: true
size: 16:9
header: "Seguridad Informática Avanzada - Proyecto final 2026-2"
footer: "FI UNAM - Equipo otp-secured-cloud"
---

# Servicio de almacenamiento con autenticación de doble factor por OTP

**Proyecto final de Seguridad Informática Avanzada**

Facultad de Ingeniería UNAM, semestre 2026-2

Equipo otp-secured-cloud

29 de mayo de 2026

---

# Equipo

| Integrante | Correo |
|---|---|
| Arellanes Conde Esteban | esteban.arellanes@ingenieria.unam.edu |
| Ferreira Rojas Mauricio | mauferreira183@gmail.com |
| López Segundo Luis Iván | lopezsknd@gmail.com |
| Olvera González Arely | arely.olvera@ingenieria.unam.edu |
| Rufino López María Elena | mariaelena.rufino424@gmail.com |
| Salgado Miranda Jorge | ohchochy@gmail.com |

Repositorio público: https://github.com/chochy2001/otp-secured-cloud

---

# Objetivo

Construir un servicio de almacenamiento de archivos donde el control de acceso se demuestre en las tres capas que el profesor confirmó como evaluables:

1. Identificación
2. Autenticación con dos factores
3. Autorización

La cuarta capa (auditoría) se incluye como complemento académico pero no se evalúa, según indicación del profesor por correo. El segundo factor se exige siempre y los archivos se cifran del lado servidor. Cada decisión queda evidenciada por un script reproducible.

---

# Las cuatro capas del control de acceso

| Capa | Pregunta | Componente del proyecto | Evaluable |
|---|---|---|---|
| Identificación | Quién dice ser el usuario | OpenLDAP con UIDs únicos | Sí |
| Autenticación | Lo demuestra | Contraseña LDAP + OTP TOTP | Sí |
| Autorización | Qué puede hacer | Permisos de OwnCloud y OCS Sharing | Sí |
| Auditoría | Qué hizo y cuándo | Logs de los tres componentes | No (complemento académico) |

El profesor confirmó por correo que solo revisará las primeras tres capas. La cuarta queda documentada para completar el marco que él mismo presentó en clase.

---

# Stack tecnológico

| Componente | Software | Versión |
|---|---|---|
| Directorio de usuarios | OpenLDAP en `osixia/openldap` | 1.5.0 |
| Servidor de tokens OTP | privacyIDEA | 3.10.2 |
| Cliente OTP móvil | FreeOTP | App de Red Hat |
| Almacenamiento | OwnCloud Server | 10.15.3 |
| Base de datos | MariaDB | 10.11 |
| Caché | Redis | 7-alpine |
| Terminador TLS | Caddy | 2-alpine |
| Plataforma | Docker Compose v2 | actual |

---

# Conceptos básicos: 2FA

Tres categorías de factores:

- **Conocimiento**: contraseña, PIN. Es lo más fácil de robar.
- **Posesión**: token físico, OTP en el teléfono. Reduce el riesgo de phishing puro.
- **Inherencia**: biometría. Útil para desbloqueo del dispositivo, no para autenticación remota directa.

2FA exige dos factores de **categorías distintas**. Dos contraseñas no son 2FA.

En este proyecto: contraseña LDAP (conocimiento) más OTP TOTP en FreeOTP (posesión).

---

# HOTP y TOTP

**HOTP** (RFC 4226): basado en un contador. El servidor y el dispositivo comparten un secreto y un contador. Cada uso incrementa el contador en ambos lados. Si pierden sincronía, hay que resincronizar.

**TOTP** (RFC 6238): variante de HOTP donde el contador es el tiempo dividido en ventanas de 30 segundos. No depende de mantener un contador acoplado.

Por eso TOTP ganó: cualquier dispositivo con un reloj NTP correcto puede generar el código sin acoplarse al servidor.

---

# Cómo se calcula un código TOTP

```
counter = floor(unix_time / 30)
hash    = HMAC-SHA1(secret, counter)
offset  = hash[19] AND 0x0F
code    = (read_4_bytes(hash, offset) AND 0x7FFFFFFF) mod 1000000
```

El código son 6 dígitos. Cada 30 segundos se renueva.

El secreto se comparte una sola vez al enrolar (típicamente como código QR `otpauth://`). FreeOTP lo guarda cifrado en el llavero del teléfono.

---

# Diseño del árbol LDAP

```
dc=sia,dc=unam,dc=mx
|
|-- cn=admin
|-- ou=Usuarios
|   |-- ou=Desarrollo
|   |   |-- uid=usuario.desarrollo1
|   |   |-- uid=usuario.desarrollo2
|   |   `-- uid=usuario.desarrollo3
|   `-- ou=Seguridad
|       |-- uid=usuario.seguridad1
|       |-- uid=usuario.seguridad2
|       `-- uid=usuario.seguridad3
|-- ou=Grupos
`-- ou=Servicios
    `-- cn=svc-owncloud
```

---

# Decisiones del árbol LDAP

- **Base DN `dc=sia,dc=unam,dc=mx`**: refleja el contexto académico (SIA + UNAM).
- **Atributo de login `uid`**: convención OpenLDAP estándar.
- **`objectClass: inetOrgPerson` para humanos**: da `uid`, `cn`, `mail`, `userPassword`.
- **Cuenta de servicio aparte**: `cn=svc-owncloud,ou=Servicios` con `objectClass: simpleSecurityObject + organizationalRole + top`. NO es `inetOrgPerson` para que el filtro `(objectClass=inetOrgPerson)` retorne exactamente 6 humanos.
- **ACL específica**: la cuenta de servicio puede leer usuarios pero no `userPassword`.

---

# privacyIDEA: arquitectura

privacyIDEA es el servidor de tokens. NO mantiene usuarios propios: lee del LDAP a través de un *resolver*.

| Concepto | Valor en el proyecto |
|---|---|
| Resolver | `sia-ldap` apuntando a `ldaps://openldap:636` |
| Realm | `sia` (agrupa al resolver, marcado por defecto) |
| Almacenamiento de tokens | SQLite en volumen Docker |
| API | REST sobre HTTPS en puerto 8443 |
| Admin web | `https://localhost:8443` |

Esto significa que dar de baja un usuario en LDAP lo desactiva automáticamente en privacyIDEA y en OwnCloud.

---

# Enrolamiento de un token TOTP

Pasos automatizados por `scripts/privacyidea-enroll-test-token.sh`:

1. `POST /auth` con admin y password, recibe token de sesión.
2. `DELETE /token/<serial>` borra cualquier token previo (idempotencia).
3. `POST /token/init` con `type=totp`, `genkey=1`, `user`, `realm`. privacyIDEA genera la semilla y devuelve la URL `otpauth://`.
4. El script imprime la URL para escanear con FreeOTP y, además, calcula el OTP local con Python para validarlo contra `POST /validate/check` sin depender de un teléfono.

La URL `otpauth://totp/...?secret=...&period=30&digits=6` es el QR que cualquier app TOTP entiende.

---

# OwnCloud: integración LDAP

OwnCloud usa el app `user_ldap` (no `user_ldap_ng`). Se configura con `occ ldap:set-config` por línea de comandos.

Campos que pide el wizard, llenados por `scripts/owncloud-configure.sh`:

| Campo | Valor |
|---|---|
| Host | `openldap` |
| Port | `636` (LDAPS) |
| Base DN usuarios | `ou=Usuarios,dc=sia,dc=unam,dc=mx` |
| Base DN grupos | `ou=Grupos,dc=sia,dc=unam,dc=mx` |
| Bind DN | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` |
| Login Attribute | `uid` |
| User Filter | `(objectClass=inetOrgPerson)` |
| TLS | habilitado, valida contra la CA local |

---

# OwnCloud: plugin twofactor_privacyidea

App oficial de privacyIDEA para OwnCloud. Configurada con `occ`:

```
twofactor_privacyidea:url      https://privacyidea:8443/
twofactor_privacyidea:checkssl true
twofactor_privacyidea:realm    sia
```

El plugin compone la ruta `/validate/check` cuando llama a privacyIDEA; en `occ` solo se registra la URL base.

Flujo de la app:

1. Usuario hace `POST /login` con usuario y password LDAP.
2. OwnCloud valida con bind LDAPS. Si pasa, marca primer factor.
3. Plugin redirige a `/login/selectchallenge`.
4. Usuario envía OTP a `/login/challenge/privacyidea`.
5. El plugin llama a `POST validate/check` de privacyIDEA con `(user, OTP, realm)`.
6. Si privacyIDEA responde `authentication=ACCEPT`, OwnCloud abre la sesión.

---

# OwnCloud: cifrado del lado servidor

Se activa con `occ encryption:enable` y se selecciona el módulo por defecto:

```
occ encryption:enable
occ encryption:select-encryption-type masterkey
```

| Aspecto | Detalle |
|---|---|
| Algoritmo | AES-256-CTR |
| Llave | maestra única, generada al activar |
| Almacenamiento de la llave | en el mismo servidor (limitación reconocida) |
| Cabecera en disco | `HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND` |
| Transparencia | el usuario autenticado lee el archivo en claro vía WebDAV |

El cifrado funciona también para archivos compartidos: el destinatario autenticado los descifra al leer.

---

# TLS y CA propia

Toda comunicación interna y externa va por TLS:

- Una CA local generada por `scripts/generate-certs.sh` (`certs/ca.crt`, vigencia 10 años).
- Tres certificados de servidor firmados por la CA: `openldap.crt`, `privacyidea.crt`, `owncloud.crt`. Cada uno con sus SANs.
- LDAPS publicado en `localhost:6636` (mapeado al `636` interno).
- privacyIDEA en HTTPS en `localhost:8443`.
- Caddy termina TLS para OwnCloud en `localhost:9443`.
- Resolver LDAP de privacyIDEA usa `ldaps://openldap:636` con la CA local.

Los scripts pasan `--cacert certs/ca.crt` a `curl` para validar contra la CA local.

---

# Diagrama: arquitectura general

Componentes y conexiones del laboratorio:

- Usuario por HTTPS 9443 a Caddy.
- Caddy por HTTP 8080 interno a OwnCloud.
- OwnCloud por LDAPS 636 a OpenLDAP, por HTTPS 8443 a privacyIDEA y por MySQL/Redis a su base.
- privacyIDEA por LDAPS 636 a OpenLDAP.
- FreeOTP NO se conecta al servidor: solo entrega el OTP al usuario por pantalla.

(Diagrama renderizado de la figura 1: archivo `docs/figuras/figura1.png`)

---

# Demo en vivo: orden de pruebas

Dos scripts encadenados cierran las cinco validaciones evaluables del profesor:

1. `./scripts/owncloud-login-verify.sh usuario.desarrollo1`
   Confirma que el login web exige LDAP + OTP y que el archivo subido queda cifrado en disco. Cierra las validaciones iii, iv y v.

2. `./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1`
   Confirma la capa de autorización (LDAP autentica, OwnCloud autoriza) y que el destinatario lee el archivo descifrado.

`./scripts/audit-capture.sh` queda como complemento opcional. Solo se ejecuta si el profesor pregunta explícitamente por bitácoras; el bloque principal de la demo termina con los dos scripts de arriba.

---

# Demo: paso 1, login con LDAP + OTP

```bash
./scripts/owncloud-login-verify.sh usuario.desarrollo1
```

Salida esperada:

```
==> 1. Creando token TOTP de prueba para usuario.desarrollo1@sia
OK
==> 2. Login de primer factor contra OwnCloud
OK
==> 3. Enviando OTP al plugin twofactor_privacyidea
OK: OwnCloud aceptó LDAP + OTP y abrió la sesión de archivos.
==> 4. Subiendo archivo y validando cifrado en disco
OK: archivo subido y cifrado en el volumen.
```

Cierra las validaciones iii (emisión de OTP), iv (OwnCloud) y v (integración 2FA).

---

# Demo: paso 2, archivo compartido

```bash
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
```

El script:

1. Enrola TOTP para emisor y destinatario en privacyIDEA.
2. El emisor sube un archivo por WebDAV.
3. Crea el share por OCS Sharing API con `cookie + requesttoken` (Basic Auth no funciona con 2FA habilitado).
4. Verifica la cabecera `HBEGIN` en el volumen.
5. El destinatario hace login 2FA y descarga el archivo descifrado.

Cierra el último pendiente del cifrado de archivos compartidos.

---

# Demo: paso 3, cifrado en disco

Comando manual durante la presentación, después de subir el archivo:

```bash
docker exec otpsec-owncloud-server head -c 80 \
  /mnt/data/files/usuario.desarrollo1/files/demo-cifrado.txt
```

Salida (los primeros 80 bytes del archivo en disco):

```
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

El contenido en claro NO aparece. Solo OwnCloud puede descifrarlo cuando un usuario autenticado lo solicita.

---

# Auditoría: complemento académico

El profesor confirmó por correo que la cuarta capa (auditoría) no será evaluada. La incluimos como complemento del marco de control de acceso que él mismo presentó en clase.

`./scripts/audit-capture.sh` dispara los ocho eventos clave (login LDAP correcto y fallido, enrolamiento, OTP correcto y rechazado, login web 2FA exitoso y rechazado, acceso a archivo por WebDAV) y captura los logs de los tres componentes en `docs/auditoria.md`.

Disponible para consulta en el repositorio si el profesor pregunta por evidencia, no se demuestra en vivo.

---

# Mapeo a las capas evaluables

| Capa | Evidencia concreta | Donde |
|---|---|---|
| Identificación | `BIND dn="uid=usuario.desarrollo1,ou=Desarrollo,..."` | OpenLDAP |
| Autenticación primer factor | `RESULT err=0` (éxito) o `err=49` (rechazo) | OpenLDAP |
| Autenticación segundo factor | `"authentication":"ACCEPT"` o `"REJECT"` desde privacyIDEA | OwnCloud log |
| Autorización | Permisos por carpeta y por usuario en OwnCloud, OCS Sharing API, WebDAV PUT/GET con `"user":"usuario.desarrolloN"` | OwnCloud |

Las tres capas evaluables se demuestran en vivo durante el bloque de demo con `owncloud-login-verify.sh` y `owncloud-share-verify.sh`.

---

# Reproducibilidad

Toda la solución se levanta en menos de 10 minutos en una laptop moderna:

```bash
git clone git@github.com:chochy2001/otp-secured-cloud.git
cd otp-secured-cloud
./scripts/generate-certs.sh
docker compose -f compose/docker-compose.yml --env-file .env up -d
./scripts/ldap-verify.sh
./scripts/privacyidea-configure.sh && ./scripts/privacyidea-verify.sh
./scripts/owncloud-configure.sh && ./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo1
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
```

Si todos terminan con `Todo OK` u `OK`, el laboratorio está operativo. `./scripts/audit-capture.sh` queda como complemento opcional, ya que la auditoría no se evalúa.

---

# Limitaciones aceptadas a propósito

Decisiones académicas que serían inaceptables en producción:

1. `.env` con contraseñas en texto plano se versiona en el repo.
2. Las contraseñas son débiles y compartidas (`sia-user-2026` para los seis usuarios).
3. Los LDIF originales contienen `userPassword` en texto plano.
4. CA y certificados son autofirmados.
5. Sin alta disponibilidad, sin backup automatizado, sin segmentación de red interna.
6. Sin rate limiting ni lockout más allá de los defaults de cada componente.
7. La llave maestra del cifrado vive en el mismo servidor que los archivos cifrados.

Lista completa: sección "Aviso de seguridad" del README.

---

# Lo que cambiaríamos en un entorno real

| Limitación | Fix de producción |
|---|---|
| `.env` versionado | HashiCorp Vault, AWS Secrets Manager o variables de CI |
| Password compartido | Política de complejidad, rotación y único por usuario |
| LDIF con `userPassword` plano | Hashear con `slappasswd -s` antes de importar |
| CA propia | Let's Encrypt o CA corporativa |
| Una sola instancia | Replicación (slapd N+1, MariaDB Galera, OwnCloud detrás de balanceador) |
| Master key local | Cifrado extremo a extremo del lado cliente |
| Sin SIEM | Reenvío a Loki/Splunk/ELK con dashboards y alertas |

---

# Conclusión por equipo

El proyecto convirtió cuatro conceptos teóricos del control de acceso (identificación, autenticación, autorización, auditoría) en piezas concretas y verificables. Cada validación del profesor se cierra con un script reproducible.

Lo más útil del ejercicio fue la disciplina de documentar antes de implementar y de escribir un verificador para cada decisión: cuando hubo que mover OwnCloud a HTTPS o reorganizar el árbol LDAP, ya estaba claro qué cambiaba y dónde se rompía.

Las limitaciones aceptadas las documentamos honestamente. Saber dónde están los huecos también es parte del aprendizaje.

---

# Preguntas

¿Cómo se podría endurecer el cifrado para no depender de la llave maestra local?

¿Qué pasaría si privacyIDEA quedara fuera de servicio durante una jornada laboral?

¿Cómo se integraría auditoría centralizada (Loki, Splunk) sobre los logs que ya emite cada componente?

¿Cuál es el costo en latencia de cifrar y descifrar cada archivo en cada lectura?

Estamos abiertos a sugerencias del profesor sobre qué pieza profundizar.

---

# Gracias

Repositorio: https://github.com/chochy2001/otp-secured-cloud

Memoria técnica completa en `docs/memoria-tecnica.md`.

Bitácoras reales de los 8 eventos de auditoría en `docs/auditoria.md`.

Equipo: Arellanes, Ferreira, López, Olvera, Rufino, Salgado.

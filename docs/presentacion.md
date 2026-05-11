---
marp: true
theme: default
paginate: true
size: 16:9
header: "Seguridad Informática Avanzada - Proyecto final 2026-2"
footer: "FI UNAM - Equipo otp-secured-cloud"
---

<style>
section {
  font-family: "Aptos", "Inter", "Helvetica Neue", Arial, sans-serif;
  color: #111827;
  background: #f7f8fb;
}
section.lead {
  color: #f8fafc;
  background: linear-gradient(135deg, #0f172a 0%, #164e63 55%, #0f766e 100%);
}
section.dark {
  color: #f8fafc;
  background: #111827;
}
h1 {
  color: #0f766e;
  font-size: 44px;
  letter-spacing: 0;
}
section.lead h1,
section.dark h1 {
  color: #ffffff;
}
h2, h3 {
  color: #164e63;
}
strong {
  color: #0f766e;
}
section.lead strong,
section.dark strong {
  color: #5eead4;
}
table {
  font-size: 24px;
}
code {
  color: #0f172a;
  background: #e2e8f0;
  border-radius: 4px;
  padding: 2px 6px;
}
section.dark code,
section.lead code {
  color: #f8fafc;
  background: rgba(255, 255, 255, 0.16);
}
.kicker {
  color: #0f766e;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  font-size: 22px;
}
section.lead .kicker,
section.dark .kicker {
  color: #99f6e4;
}
.claim {
  font-size: 34px;
  line-height: 1.18;
  font-weight: 700;
}
.metric {
  font-size: 54px;
  color: #0f766e;
  font-weight: 800;
}
section.dark .metric,
section.lead .metric {
  color: #5eead4;
}
.small {
  font-size: 22px;
}
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
}
.card {
  background: #ffffff;
  border: 1px solid #dbe3ef;
  border-radius: 8px;
  padding: 20px;
}
section.dark .card,
section.lead .card {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.22);
}
.tag {
  display: inline-block;
  border: 1px solid #94a3b8;
  border-radius: 999px;
  padding: 4px 12px;
  margin: 4px 4px 4px 0;
  font-size: 20px;
}
</style>

<!-- _class: lead -->

# otp-secured-cloud

<div class="kicker">Proyecto final SIA - FI UNAM - 2026-2</div>

Servicio de almacenamiento con **LDAP + OTP + OwnCloud**, listo para demostrarse de punta a punta.

<br>

**Una sola instrucción levanta, configura y valida el laboratorio:**

```bash
./scripts/bootstrap.sh
```

---

# La promesa

<div class="claim">
No solo montamos servicios: construimos un flujo completo donde cada acceso queda probado por código.
</div>

| Lo que se evalúa | Cómo se demuestra |
|---|---|
| Alta de usuarios LDAP | Directorio con 6 usuarios humanos y cuenta de servicio |
| Integración privacyIDEA | Resolver LDAP por LDAPS y realm `sia` |
| Token OTP | TOTP enrolado y validado contra API |
| OwnCloud | LDAP, 2FA, TLS y cifrado activos |
| 2FA LDAP + OTP | Login web real con primer y segundo factor |

---

# Resultado final

<div class="grid">
<div class="card">

<div class="metric">6</div>

Usuarios humanos en LDAP, separados por OU.

</div>
<div class="card">

<div class="metric">3</div>

Canales TLS: LDAPS, privacyIDEA HTTPS y OwnCloud HTTPS.

</div>
<div class="card">

<div class="metric">5</div>

Validaciones evaluables cerradas con scripts reproducibles.

</div>
<div class="card">

<div class="metric">1</div>

Comando para levantar y validar todo.

</div>
</div>

---

# Equipo y responsabilidades

| Integrante | Aporte principal |
|---|---|
| **Salgado Miranda Jorge** | Integración general, Docker Compose, automatización, QA, cierre técnico y repositorio |
| Arellanes Conde Esteban | Demo en vivo y explicación del flujo end-to-end |
| Ferreira Rojas Mauricio | privacyIDEA, FreeOTP y validación del segundo factor |
| López Segundo Luis Iván | Diseño del árbol LDAP y modelo de usuarios |
| Olvera González Arely | Marco conceptual 2FA/OTP y documentación base |
| Rufino López María Elena | OwnCloud, permisos, compartición y cifrado |

---

# Qué hizo Jorge

<div class="claim">
El rol de integración fue convertir piezas sueltas en un sistema que se pueda clonar, levantar y defender frente al profesor.
</div>

- Orquestación Docker Compose de OpenLDAP, privacyIDEA, OwnCloud, MariaDB, Redis y Caddy.
- Script `bootstrap.sh`: certificados, build, healthchecks, configuración y pruebas.
- QA de consistencia: `shellcheck`, `bash -n`, `docker compose config`, `git diff --check`.
- Cierre funcional: LDAPS, HTTPS, 2FA, cifrado, carpetas compartidas y docs alineadas.
- Repositorio GitHub, README, estado del proyecto y notas de cierre.

---

# Arquitectura en una frase

<div class="claim">
LDAP identifica y valida password; privacyIDEA valida posesión del token; OwnCloud decide permisos y almacena archivos cifrados.
</div>

<span class="tag">OpenLDAP</span>
<span class="tag">privacyIDEA</span>
<span class="tag">FreeOTP</span>
<span class="tag">OwnCloud</span>
<span class="tag">MariaDB</span>
<span class="tag">Redis</span>
<span class="tag">Caddy</span>
<span class="tag">Docker Compose</span>

---

# Arquitectura general

![bg right:52% fit](figuras/figura1.png)

1. Usuario entra por `https://localhost:9443`.
2. Caddy termina TLS y reenvía a OwnCloud.
3. OwnCloud consulta usuarios por LDAPS.
4. OwnCloud valida OTP con privacyIDEA.
5. privacyIDEA usa el mismo LDAP como fuente de identidad.
6. OwnCloud guarda archivos en disco con cifrado del lado servidor.

---

# Flujo de autenticación

![bg right:52% fit](figuras/figura2.png)

1. Usuario envía `uid + password`.
2. OwnCloud hace bind LDAPS contra OpenLDAP.
3. Si el password es correcto, OwnCloud pide segundo factor.
4. Usuario escribe TOTP generado por FreeOTP.
5. Plugin `twofactor_privacyidea` consulta `/validate/check`.
6. Si privacyIDEA acepta, OwnCloud abre la sesión.

---

# Árbol LDAP

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
|-- ou=Grupos
`-- ou=Servicios
    `-- cn=svc-owncloud
```

La cuenta de servicio no es usuario humano: queda fuera del filtro `(objectClass=inetOrgPerson)`.

---

# Decisiones LDAP que sí importan

| Decisión | Motivo |
|---|---|
| `uid` como login | Convención LDAP simple y estable |
| 6 usuarios humanos | Permite probar dos áreas sin ruido |
| `svc-owncloud` separado | OwnCloud y privacyIDEA no usan `cn=admin` |
| ACL dedicada | Servicio lee usuarios, pero no `userPassword` |
| LDAPS | Passwords y binds no viajan en claro |
| Passwords `{SSHA}` en LDIF | No quedan contraseñas planas en bootstrap |

---

# privacyIDEA y FreeOTP

privacyIDEA no duplica identidades. Lee a los usuarios desde LDAP mediante:

| Concepto | Valor |
|---|---|
| Resolver | `sia-ldap` |
| URI | `ldaps://openldap:636` |
| Realm | `sia` |
| API | `https://localhost:8443` |
| Token | TOTP de 6 dígitos cada 30 s |

FreeOTP solo guarda el secreto TOTP y muestra el código; no se conecta al servidor.

---

# Enrolamiento TOTP

El script `privacyidea-enroll-test-token.sh` automatiza el flujo que normalmente se haría desde la UI:

1. Autentica al admin en privacyIDEA.
2. Borra token de prueba anterior del usuario.
3. Crea token TOTP con `genkey=1`.
4. Imprime la URL `otpauth://` para FreeOTP.
5. Calcula el TOTP localmente en Python.
6. Valida el código contra `/validate/check`.

Esto prueba emisión de token sin depender de que el teléfono esté disponible.

---

# OwnCloud como punto de control

OwnCloud queda configurado con tres responsabilidades:

| Responsabilidad | Mecanismo |
|---|---|
| Usuarios | App `user_ldap` conectado por LDAPS |
| Segundo factor | App `twofactor_privacyidea` |
| Autorización | Permisos de carpetas y OCS Sharing API |
| Cifrado | Server Side Encryption con master key |

Punto clave para defender: **LDAP autentica; OwnCloud autoriza**.

---

# Cifrado de archivos

Se activa el módulo de cifrado de OwnCloud y se verifica con:

```bash
occ encryption:status
occ config:app:get encryption useMasterKey
```

En disco, un archivo real empieza así:

```text
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

El usuario autorizado lo lee en claro por WebDAV, pero el volumen Docker no guarda el contenido plano.

---

# Carpeta compartida

El flujo de autorización se prueba con dos usuarios distintos:

1. `usuario.desarrollo1` sube un archivo por WebDAV.
2. Crea un share hacia `usuario.seguridad1` por OCS Sharing API.
3. Se verifica que el archivo en disco sigue cifrado.
4. `usuario.seguridad1` inicia sesión con LDAP + OTP.
5. El destinatario descarga el archivo y lee el contenido descifrado.

Esto demuestra que la autorización vive en OwnCloud, no en LDAP.

---

# TLS y CA propia

| Servicio | Canal |
|---|---|
| OpenLDAP | `ldaps://openldap:636`, publicado en `localhost:6636` |
| privacyIDEA | `https://localhost:8443` |
| OwnCloud | `https://localhost:9443`, detrás de Caddy |

`scripts/generate-certs.sh` crea una CA local y tres certificados con SANs correctos.

Los scripts usan `--cacert certs/ca.crt`, así que no se valida con `-k` ni se desactiva TLS.

---

# Automatización de arranque

```bash
./scripts/bootstrap.sh
```

Hace todo lo necesario:

- Genera o reutiliza certificados.
- Levanta Docker Compose con `--build`.
- Espera healthchecks de los 6 contenedores.
- Configura privacyIDEA y OwnCloud.
- Corre pruebas de LDAP, OTP, OwnCloud, login 2FA, cifrado y share.

Para demo rápida con repo ya clonado:

```bash
./scripts/bootstrap.sh --no-build
```

---

# Healthchecks y dependencias

La estabilidad de la demo no depende de "esperar a ojo".

| Servicio | Healthcheck |
|---|---|
| OpenLDAP | `ldapwhoami` |
| privacyIDEA | HTTPS con CA local |
| MariaDB | `mysqladmin ping` |
| Redis | `redis-cli ping` |
| OwnCloud | `status.php` |
| Caddy | `status.php` por HTTPS |

Compose arranca servicios según dependencias sanas, no solo contenedores encendidos.

---

# Auditoría como complemento

No se evalúa, pero queda lista si el profesor pregunta:

```bash
./scripts/audit-capture.sh
```

Captura 8 eventos:

- Login LDAP correcto y fallido.
- Enrolamiento TOTP.
- OTP correcto y rechazado.
- Login web 2FA exitoso y rechazado.
- Acceso a archivo por WebDAV.

La evidencia queda en `docs/auditoria.md`.

---

# Cumplimiento contra el PDF

| Punto solicitado | Estado | Evidencia |
|---|---|---|
| Alta de usuarios LDAP | Cerrado | `ldap-verify.sh` |
| Integración privacyIDEA | Cerrado | `privacyidea-verify.sh` |
| Emisión OTP FreeOTP | Cerrado | `privacyidea-enroll-test-token.sh` |
| Implementación OwnCloud | Cerrado | `owncloud-verify.sh` |
| 2FA LDAP + OTP | Cerrado | `owncloud-login-verify.sh` |
| Compartición y cifrado | Cerrado | `owncloud-share-verify.sh` |

---

# Reproducibilidad

El evaluador no necesita memorizar comandos.

Si el repo ya está clonado:

```bash
cd otp-secured-cloud
./scripts/bootstrap.sh
```

Si solo queremos levantar sin reconstruir imágenes:

```bash
./scripts/bootstrap.sh --no-build
```

Si termina con `Listo`, el laboratorio quedó operativo.

---

# Qué nos puede preguntar el profesor

| Pregunta probable | Respuesta corta |
|---|---|
| Por qué LDAP y no usuarios locales | LDAP centraliza identidad; OwnCloud solo consume |
| Dónde vive autorización | En OwnCloud: permisos y OCS Sharing |
| Qué valida privacyIDEA | Posesión del secreto TOTP asociado al usuario |
| Por qué FreeOTP no se conecta | TOTP se calcula localmente; solo el código se escribe |
| Qué pasa si roban password | Sin OTP no se abre sesión |
| Qué pasa si roban el servidor | Master key local no protege contra admin del servidor |

---

# Limitaciones honestas

| Decisión académica | Producción real |
|---|---|
| `.env` versionado | Gestor de secretos |
| Password compartido | Password único, rotación, MFA recovery |
| CA local | CA corporativa o pública |
| Una instancia por servicio | HA, backups, monitoreo |
| Master key local | Cifrado extremo a extremo |
| Sin SIEM | Envío a Loki, Splunk o ELK |

No se ocultan: están en el README porque forman parte del criterio técnico.

---

# Cómo se vende el proyecto

<div class="claim">
Es un laboratorio pequeño, pero con disciplina de sistema real: TLS, cuentas de servicio, healthchecks, pruebas, reproducibilidad y límites documentados.
</div>

El valor no está solo en que "encienda". Está en que podemos explicar por qué cada pieza existe y demostrarla con salida verificable.

---

# Demo al final

La demo se hace **después de terminar las diapositivas**.

No clonamos en vivo. El repositorio ya está en la laptop.

```bash
cd /Users/jorge/Documents/Escuela/SIA/Proyecto_Final
./scripts/bootstrap.sh --no-build
./scripts/owncloud-login-verify.sh usuario.desarrollo1
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
```

Si el profesor pide ver la UI: abrir `https://localhost:9443`.

---

# Demo: qué debe verse

1. Los 6 contenedores `healthy`.
2. OpenLDAP encuentra exactamente 6 usuarios humanos.
3. privacyIDEA valida realm y resolver LDAP.
4. OwnCloud resuelve usuarios por LDAPS.
5. Login web pasa password LDAP y exige OTP.
6. Archivo queda cifrado en disco.
7. Usuario destino lee archivo compartido descifrado.

La demo no agrega promesas nuevas: muestra exactamente lo que ya se implementó.

---

# Cierre

<div class="claim">
El proyecto cumple el PDF, se puede defender técnicamente y se puede reproducir sin depender de memoria.
</div>

Repositorio:

```text
https://github.com/chochy2001/otp-secured-cloud
```

Documentos clave: `README.md`, `docs/memoria-tecnica.md`, `docs/como-probar.md`.

---

# Preguntas

Estamos listos para profundizar en:

- Diseño LDAP y ACLs.
- Flujo TOTP y privacyIDEA.
- OwnCloud, autorización y cifrado.
- TLS y CA local.
- Automatización con Docker Compose.
- Limitaciones y cambios necesarios para producción.

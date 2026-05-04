# Guion de exposición - 30 minutos

Material de trabajo para el ensayo. Distribuye los 30 minutos entre los 6 integrantes y deja la demo en vivo como punto central.

## Distribución por integrante

| Bloque | Tiempo | Responsable | Tema |
|---|---|---|---|
| 0. Intro y contexto | 2 min | Salgado Miranda Jorge | Apertura, integrantes, objetivo del proyecto, las 4 capas |
| 1. Marco conceptual: 2FA, OTP, TOTP, HOTP | 4 min | Olvera González Arely | Por qué 2FA, definiciones formales, diferencias entre HOTP y TOTP |
| 2. Diseño del árbol LDAP y cuentas de servicio | 4 min | López Segundo Luis Iván | Base DN, OUs, NHI, ACL, evidencia con `ldap-verify.sh` |
| 3. privacyIDEA y enrolamiento con FreeOTP | 4 min | Ferreira Rojas Mauricio | Resolver, realm, ciclo de vida del token, FreeOTP en pantalla |
| 4. OwnCloud y orquestación 2FA | 4 min | Rufino López María Elena | Plugin twofactor_privacyidea, login web, cifrado del lado servidor |
| 5. Demo en vivo: login + share + cifrado en disco | 6 min | Arellanes Conde Esteban | `owncloud-login-verify.sh`, `owncloud-share-verify.sh`, mostrar HBEGIN |
| 6. Auditoría: bitácoras y las 4 capas verificadas | 3 min | Salgado Miranda Jorge | `audit-capture.sh`, mostrar `docs/auditoria.md` |
| 7. Conclusiones, limitaciones y preguntas | 3 min | Todos rotando | Lo aceptado a propósito, lo que cambiaríamos, dudas del profesor |

Total: 30 minutos exactos. Si se atrasa el bloque 5 (demo), se acortan los bloques 6 y 7.

## Apertura (2 minutos) - Salgado Miranda Jorge

**Apertura, ronda de presentación, marco general del proyecto.**

Mensaje clave: "Construimos un servicio de almacenamiento donde el control de acceso se prueba en sus cuatro capas."

Pasos:
1. Saludo y nombre del proyecto.
2. Presentar al equipo en orden alfabético (apellido).
3. Mostrar la diapositiva con el mapeo de las 4 capas a los componentes (LDAP, privacyIDEA, OwnCloud, logs).
4. Anunciar el formato: 5 bloques temáticos, 1 demo, conclusiones y preguntas.

## Bloque 1: Marco conceptual - Olvera González Arely (4 minutos)

**Por qué 2FA y qué tipos de OTP existen.**

Mensaje clave: "Una contraseña sola no alcanza; OTP basado en tiempo es el estándar industrial de bajo costo."

Pasos:
1. Tres factores de autenticación (conocer/tener/ser). Ejemplo concreto de cada uno.
2. Por qué 2FA reduce drásticamente el riesgo de robo de cuenta. Cifra de Verizon DBIR si quieren citarla.
3. HOTP (RFC 4226) vs TOTP (RFC 6238). Por qué TOTP ganó.
4. Estructura de un código TOTP: secreto compartido + tiempo dividido en ventanas de 30 s.
5. Mencionar FreeOTP como cliente y privacyIDEA como servidor del proyecto.

Apoyo visual: una sola lámina con un diagrama de TOTP (semilla + reloj = código).

## Bloque 2: Diseño del árbol LDAP - López Segundo Luis Iván (4 minutos)

**Cómo se modeló el directorio y por qué.**

Mensaje clave: "El árbol LDAP es la fuente de verdad de identidades; cada decisión de DN tiene una razón."

Pasos:
1. Mostrar el árbol final: `dc=sia,dc=unam,dc=mx` con OUs `Usuarios/Desarrollo`, `Usuarios/Seguridad`, `Servicios`.
2. Por qué separamos cuentas humanas de cuentas de servicio (NHI). Filtro `(objectClass=inetOrgPerson)` retorna 6, no 7.
3. Cuenta `cn=svc-owncloud,ou=Servicios,...` con `simpleSecurityObject + organizationalRole`. ACL específica que niega lectura de `userPassword`.
4. LDAPS publicado en `localhost:6636` con la CA del proyecto.
5. Ejecutar en vivo `./scripts/ldap-verify.sh`. Esperan ver "Todo OK" con los 8 checks.

## Bloque 3: privacyIDEA y FreeOTP - Ferreira Rojas Mauricio (4 minutos)

**Cómo se administran y validan los OTP.**

Mensaje clave: "privacyIDEA es el servidor de tokens; FreeOTP es solo un cliente que sigue el estándar TOTP."

Pasos:
1. Mostrar el panel de privacyIDEA en `https://localhost:8443`. Login con `admin`.
2. Concepto de Resolver y Realm. Mostrar `sia-ldap` y `sia` por defecto.
3. Enrolar un token TOTP en vivo: `./scripts/privacyidea-enroll-test-token.sh usuario.desarrollo3`. Mostrar la URL `otpauth://`.
4. Si hay tiempo, escanear el QR en un teléfono real con FreeOTP previamente preparado, o explicar que el script ya valida el OTP localmente sin teléfono.
5. Validar un OTP arbitrario contra `/validate/check` con `./scripts/privacyidea-validate-otp.sh`.

## Bloque 4: OwnCloud y 2FA - Rufino López María Elena (4 minutos)

**Cómo se orquesta todo desde la perspectiva del usuario final.**

Mensaje clave: "OwnCloud no implementa 2FA; delega a privacyIDEA mediante un plugin oficial."

Pasos:
1. Abrir `https://localhost:9443` en un navegador limpio (modo incógnito recomendado para la demo).
2. Mostrar el flujo: usuario + password LDAP, redirección al selector de 2FA, ingreso del OTP, vista de archivos.
3. Explicar la configuración: `user_ldap` apunta a LDAPS, `twofactor_privacyidea` apunta a HTTPS interno con la CA local.
4. Mostrar que el cifrado del lado servidor está activo (`occ encryption:status` o desde el panel admin).
5. Subir un archivo desde la UI y abrir el volumen de Docker para mostrar la cabecera `HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND`.

## Bloque 5: Demo en vivo - Arellanes Conde Esteban (6 minutos)

**Reproducción end-to-end con scripts.**

Mensaje clave: "No describimos la solución; la demostramos. Los scripts son la prueba."

Pasos:
1. Mostrar la terminal con la raíz del repo. Verificar que `docker compose ps` muestra los 6 contenedores en `Up`.
2. Ejecutar `./scripts/owncloud-login-verify.sh usuario.desarrollo1`. Cuando termine "OK: archivo subido y cifrado en el volumen", explicar paso a paso lo que validó.
3. Ejecutar `./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1`. Cuando termine "OK: usuario.seguridad1 descifró y leyó el archivo compartido", aclarar que ese mensaje cierra la pregunta del profesor sobre cifrado de archivos compartidos.
4. Mostrar el archivo en disco con `docker exec otpsec-owncloud-server head -c 80 /mnt/data/files/usuario.desarrollo1/files/demo-compartido-usuario.desarrollo1.txt`. La cabecera `HBEGIN` debe ser visible.
5. Plan B: si la demo en vivo falla, mostrar la grabación de respaldo (ver bloque "Plan B" abajo).

## Bloque 6: Auditoría - Salgado Miranda Jorge (3 minutos)

**Las cuatro capas no son teóricas; aquí está la evidencia.**

Mensaje clave: "Logs reales de los tres componentes para los 8 eventos clave del control de acceso."

Pasos:
1. Ejecutar `./scripts/audit-capture.sh`. Tarda menos de 90 s. Aprovechar el tiempo para explicar qué eventos cubre.
2. Abrir `docs/auditoria.md` recién generado. Mostrar tres ejemplos:
   - Sección 2 (LDAP fallido): `RESULT err=49 text=` en `docker logs otpsec-openldap`.
   - Sección 6 (OwnCloud LDAP+OTP exitoso): `"authentication":"ACCEPT"` y `"User authenticated successfully!"` en `owncloud.log`.
   - Sección 7 (OTP rechazado): `"wrong otp value"` con el OTP `000000`.
3. Recordar que los tres niveles del control (identificación, autenticación, autorización) producen registros automáticos y que esos registros son la cuarta capa.

## Bloque 7: Conclusiones y preguntas - Todos (3 minutos)

**Cierre sincero y honesto.**

Mensaje clave: "Sabemos qué cosas serían inaceptables en producción y por qué las dejamos así para fines didácticos."

Pasos:
1. Cada integrante (en una sola línea cada uno) menciona un aprendizaje técnico personal.
2. Listar las limitaciones aceptadas a propósito: `.env` versionado, certs autofirmados, master key en el mismo servidor, sin alta disponibilidad. Recordar la sección "Aviso de seguridad" del README.
3. Listar las dos o tres cosas que cambiaríamos en un entorno real.
4. Abrir preguntas del profesor.

## Plan B: si la demo falla

1. **Snapshot del entorno**: tener una grabación de pantalla de los scripts corriendo correctamente, lista para reproducir si docker no levanta. Hacer la grabación con `asciinema` o un screen recorder al menos 24 h antes de la presentación. Ubicación sugerida: `docs/respaldos/demo-end-to-end.cast` (no se versiona en el repo público).
2. **Ambiente respaldo**: tener el laptop de un segundo integrante listo con el repo clonado y los contenedores levantados, encendido durante toda la presentación.
3. **Slides con capturas de pantalla**: que muestren el `Todo OK` final de cada script, por si lo demás falla.

## Logística

- Llegar 20 minutos antes para verificar proyector, audio, conexión y ambiente Docker.
- Una sola laptop al frente. Cambiar de presentador NO debe implicar cambiar de máquina.
- Tener `https://localhost:9443` ya abierto en una pestaña antes de empezar.
- Tener una segunda terminal abierta con la raíz del proyecto, lista para ejecutar comandos sin teclear desde cero.
- Si vuestro horario es a primera hora, calienta el stack 5 minutos antes para que los caches estén templados.

## Apuntes para el ensayo

Hacer al menos un ensayo completo grabado al menos 48 horas antes. El objetivo del ensayo:
- Detectar bloques que rebasan su tiempo asignado.
- Confirmar que las transiciones entre integrantes son fluidas.
- Confirmar que la demo corre completa sin intervenciones.
- Resolver dudas del equipo entre sí en privado, no frente al profesor.

Si en el ensayo el total se va a 35 minutos, recortar conscientemente bloques 1 y 7 antes de tocar la demo.

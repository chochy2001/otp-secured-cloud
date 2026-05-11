# Guion de exposición - 30 minutos

Material de trabajo para el ensayo. La presentación primero vende la solución y explica la arquitectura; la demo queda al final para mostrar el sistema ya construido, sin improvisar comandos ni clonar en vivo.

## Distribución general

| Bloque | Tiempo | Responsable | Tema |
|---|---:|---|---|
| 0. Apertura y promesa | 3 min | Salgado Miranda Jorge | Qué se construyó, qué evalúa el profesor y por qué el proyecto es defendible |
| 1. Marco conceptual | 3 min | Olvera González Arely | 2FA, OTP, HOTP vs TOTP, rol de FreeOTP |
| 2. Identidad LDAP | 4 min | López Segundo Luis Iván | Árbol LDAP, usuarios, cuenta de servicio, ACL y LDAPS |
| 3. Segundo factor | 4 min | Ferreira Rojas Mauricio | privacyIDEA, resolver, realm, enrolamiento TOTP |
| 4. OwnCloud | 4 min | Rufino López María Elena | LDAP, plugin 2FA, autorización, cifrado y shares |
| 5. Integración y cierre técnico | 4 min | Salgado Miranda Jorge | Docker Compose, healthchecks, `bootstrap.sh`, pruebas y QA |
| 6. Demo final | 7 min | Arellanes Conde Esteban, con apoyo de Jorge | Levantar/verificar, login LDAP+OTP, cifrado, share |
| 7. Cierre | 1 min | Todos | Limitaciones honestas y preguntas |

Total: 30 minutos. Si el tiempo se aprieta, se recortan explicaciones, no la demo.

## Tesis de la presentación

Frase que debe quedar clara desde el inicio:

> "LDAP identifica y valida la contraseña; privacyIDEA valida la posesión del token; OwnCloud decide permisos y almacena archivos cifrados. Todo se levanta y se prueba con un comando."

## Bloque 0: Apertura - Jorge (3 min)

Objetivo: vender el proyecto sin sonar exagerado.

Puntos:

1. Proyecto: `otp-secured-cloud`, servicio de almacenamiento con doble factor.
2. Mapeo al PDF: alta LDAP, privacyIDEA, emisión OTP, OwnCloud, 2FA LDAP+OTP.
3. Idea fuerte: no es una maqueta suelta; es un stack reproducible con pruebas.
4. Presentar al equipo y roles, destacando que Jorge llevó integración, automatización, QA y cierre técnico.

Mensaje clave:

> "Cualquier integrante o evaluador puede levantarlo desde el repo con `./scripts/bootstrap.sh` y obtener el mismo resultado."

## Bloque 1: Marco conceptual - Arely (3 min)

Objetivo: que el profesor vea que el equipo entiende el fundamento, no solo instaló herramientas.

Puntos:

1. Autenticación por factores: conocimiento, posesión, inherencia.
2. Por qué contraseña + OTP sí es 2FA.
3. HOTP vs TOTP: TOTP usa tiempo, ventana de 30 s y secreto compartido.
4. FreeOTP solo calcula el código; no se conecta al servidor.

Respuesta preparada:

> Si preguntan por seguridad de TOTP: el secreto compartido es el activo sensible. Si se filtra, el atacante puede generar códigos.

## Bloque 2: LDAP - Luis Iván (4 min)

Objetivo: defender el diseño de identidad.

Puntos:

1. Base DN: `dc=sia,dc=unam,dc=mx`.
2. OUs: `Usuarios/Desarrollo`, `Usuarios/Seguridad`, `Servicios`.
3. Seis usuarios humanos con `inetOrgPerson`.
4. Cuenta `svc-owncloud` separada: no contamina el conteo de usuarios.
5. ACL: la cuenta de servicio lee usuarios pero no `userPassword`.
6. LDAPS con CA local; no se manda password en claro.

Respuesta preparada:

> LDAP autentica identidad y contraseña. La autorización de archivos no está en LDAP; vive en OwnCloud.

## Bloque 3: privacyIDEA y FreeOTP - Mauricio (4 min)

Objetivo: explicar segundo factor como sistema, no como "código mágico".

Puntos:

1. privacyIDEA es servidor de tokens.
2. Resolver `sia-ldap` lee usuarios por LDAPS.
3. Realm `sia` agrupa el resolver.
4. Token TOTP se enrola con `genkey=1`.
5. La URL `otpauth://` es lo que FreeOTP escanea.
6. El script calcula el TOTP localmente para probar emisión sin depender del teléfono.

Respuesta preparada:

> FreeOTP no valida contra privacyIDEA. Solo muestra un número; OwnCloud manda ese número a privacyIDEA para validarlo.

## Bloque 4: OwnCloud - María Elena (4 min)

Objetivo: cerrar la parte visible para el usuario.

Puntos:

1. OwnCloud usa `user_ldap` para resolver usuarios.
2. Plugin `twofactor_privacyidea` exige segundo factor después del password.
3. Permisos y shares se administran en OwnCloud.
4. Cifrado Server Side Encryption con master key.
5. El archivo queda cifrado en disco pero el usuario autorizado lo lee en claro.

Respuesta preparada:

> El cifrado protege el archivo dentro del volumen, pero la master key vive en el servidor; no protege contra un administrador del servidor. En producción se evaluaría cifrado extremo a extremo.

## Bloque 5: Integración y cierre técnico - Jorge (4 min)

Objetivo: dar relevancia al trabajo de integración y mostrar madurez técnica.

Puntos:

1. Docker Compose une seis servicios: OpenLDAP, privacyIDEA, OwnCloud, MariaDB, Redis y Caddy.
2. Cada servicio tiene healthcheck; no se espera "a ojo".
3. `bootstrap.sh` hace certificados, build, arranque, configuración y pruebas.
4. Se corrigieron detalles de consistencia: LDIF con hashes `{SSHA}`, healthchecks TLS, verificación de master key, docs sin comandos largos.
5. QA ejecutado: `shellcheck`, `bash -n`, `docker compose config`, `git diff --check`, pruebas end-to-end.

Mensaje clave:

> "Mi parte fue convertir integraciones frágiles en un sistema repetible: clonar, levantar, validar y defender."

## Bloque 6: Demo final - Esteban con apoyo de Jorge (7 min)

Regla: la demo ocurre al final de las diapositivas. No se clona en vivo; el repo ya está en la laptop.

Comandos principales:

```bash
cd /Users/jorge/Documents/Escuela/SIA/Proyecto_Final
./scripts/bootstrap.sh --no-build
./scripts/owncloud-login-verify.sh usuario.desarrollo1
./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
```

Qué explicar mientras corre:

1. `bootstrap.sh --no-build` confirma certificados, servicios, configuración y pruebas sin reconstruir la imagen.
2. `owncloud-login-verify.sh` prueba LDAP + OTP + cifrado de archivo real.
3. `owncloud-share-verify.sh` prueba autorización por share y lectura descifrada por destinatario.
4. Mostrar `HBEGIN` si el profesor pide evidencia visual del cifrado en disco.
5. Abrir `https://localhost:9443` solo si pide ver la UI.

Frase de cierre de demo:

> "La demo muestra exactamente lo que se explicó: identidad en LDAP, segundo factor en privacyIDEA, autorización y cifrado en OwnCloud."

## Bloque 7: Cierre y preguntas - Todos (1 min)

Puntos:

1. Cumplimos los cinco puntos evaluables del PDF.
2. Auditoría queda como complemento documentado.
3. Limitaciones reales están declaradas: `.env` versionado, CA local, master key local, sin HA.
4. Invitar preguntas específicas por componente.

## Preguntas probables del profesor

| Pregunta | Respuesta corta |
|---|---|
| ¿Dónde se autentica el password? | En OpenLDAP, vía bind LDAPS. |
| ¿Dónde se valida el OTP? | En privacyIDEA, endpoint `/validate/check`. |
| ¿Dónde vive la autorización? | En OwnCloud, con permisos y OCS Sharing API. |
| ¿FreeOTP se conecta al servidor? | No. Genera TOTP localmente a partir del secreto. |
| ¿Qué pasa si roban el password? | Sin OTP, OwnCloud no abre sesión. |
| ¿Qué pasa si cae privacyIDEA? | El login 2FA falla; en producción se requeriría HA o política de break-glass. |
| ¿El cifrado protege contra el admin? | No con master key local; para eso se requiere cifrado extremo a extremo. |
| ¿Por qué no sincronizar grupos LDAP? | El profesor confirmó que LDAP autentica y OwnCloud autoriza; simplifica la demo y evita acoplar permisos al directorio. |

## Plan B

1. Si Docker está lento: correr `docker compose -f compose/docker-compose.yml --env-file .env ps` y mostrar que los contenedores están `healthy`.
2. Si falla el OTP por ventana de tiempo: esperar 30 s y repetir.
3. Si falla Caddy o puerto 9443: mostrar salida de scripts y abrir privacyIDEA/OwnCloud solo si el servicio responde.
4. Si falla todo el ambiente: usar el PDF, `docs/auditoria.md` y capturas de los `OK` finales como respaldo.

## Ensayo recomendado

Ensayar una vez con cronómetro:

- 22 minutos de explicación.
- 7 minutos de demo.
- 1 minuto de cierre.

El equipo debe practicar respuestas cortas. Si una pregunta se vuelve larga, responder primero en una frase y luego profundizar solo si el profesor pide más.

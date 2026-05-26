# Presentacion otp-secured-cloud (18 minutos, 6 presentadores)

Este archivo contiene el guion completo para la exposicion del proyecto final de Seguridad Informatica Avanzada (FI-UNAM, 2026-2). Esta pensado para ser procesado por una herramienta externa que lo convierta en slides visuales.

## Formato

- Cada slide esta separada de la siguiente por tres guiones medios (`---`).
- Al inicio de cada slide aparece: numero de slide, presentador, tiempo objetivo.
- Dentro de cada slide aparece: titulo, contenido visual que se mostrara, lo que dice el presentador (3 frases-puente: apertura, sosten, cierre) y una respuesta preparada por si el profesor interrumpe.

## Distribucion del tiempo

| Bloque | Slides | Presentador | Tema | Tiempo activo |
|---|---|---|---|---:|
| 1 | 1 a 4 | Salgado Miranda Jorge | Apertura, promesa, arquitectura, cumplimiento | 3:00 |
| 2 | 5 a 8 | Olvera Gonzalez Arely | Marco conceptual 2FA y OTP | 3:00 |
| 3 | 9 a 12 | Lopez Segundo Luis Ivan | Diseno del arbol LDAP | 3:00 |
| 4 | 13 a 16 | Ferreira Rojas Mauricio | privacyIDEA y enrolamiento TOTP | 3:00 |
| 5 | 17 a 20 | Rufino Lopez Maria Elena | OwnCloud, cifrado y compartidos | 3:00 |
| 6 | 21 a 24 | Arellanes Conde Esteban | Demo end-to-end y cierre | 3:00 |
| **Total** | **24** | **6 personas** | | **18:00** |

24 slides x 45 segundos cada una = 18 minutos. Quedan 2 minutos de margen para preguntas o transiciones.

---

**Slide 1 de 24** | **Presentador:** Salgado Miranda Jorge | **Tiempo:** 45 segundos

# Portada: otp-secured-cloud

**Proyecto final de Seguridad Informatica Avanzada**

Facultad de Ingenieria, UNAM. Semestre 2026-2.

Equipo:

- Arellanes Conde Esteban
- Ferreira Rojas Mauricio
- Lopez Segundo Luis Ivan
- Olvera Gonzalez Arely
- Rufino Lopez Maria Elena
- Salgado Miranda Jorge

Repositorio: `https://github.com/chochy2001/otp-secured-cloud`

**Lo que dice el presentador:**

1. **Apertura:** "Buen dia profesor. Somos el equipo que construyo otp-secured-cloud, un servicio de almacenamiento de archivos con autenticacion de doble factor por OTP."
2. **Sosten:** "El proyecto integra OpenLDAP, privacyIDEA, OwnCloud, MariaDB, Redis y Caddy sobre Docker Compose. Cumple los cinco puntos evaluables del PDF de la asignatura y todo se levanta y se valida desde un solo comando."
3. **Cierre:** "En los proximos dieciocho minutos vamos a recorrer las decisiones tecnicas, demostrar el cumplimiento y dejar tiempo para preguntas. Empiezo con la promesa central del proyecto."

**Respuesta preparada (si interrumpen):** "El comando es `./scripts/bootstrap.sh`. Hace certificados, build, healthchecks, configuracion y pruebas end-to-end. Termina con `Listo` si todo paso."

---

**Slide 2 de 24** | **Presentador:** Salgado Miranda Jorge | **Tiempo:** 45 segundos

# La promesa

**LDAP identifica y valida password. privacyIDEA valida posesion del token. OwnCloud decide permisos y almacena archivos cifrados.**

| Lo que pide el PDF | Como se demuestra |
|---|---|
| Alta de usuarios LDAP | 6 usuarios humanos + cuenta de servicio separada |
| Integracion privacyIDEA | Resolver LDAP por LDAPS + realm `sia` |
| Token OTP en app movil | TOTP enrolado y validado con FreeOTP o Proton Authenticator |
| OwnCloud con 2FA y cifrado | Login web real con primer y segundo factor |
| Autorizacion y compartidos | Share via OCS API + lectura descifrada por destinatario |

**Lo que dice el presentador:**

1. **Apertura:** "La promesa central es esta frase: LDAP identifica y valida password, privacyIDEA valida posesion del token, OwnCloud decide permisos y almacena archivos cifrados."
2. **Sosten:** "Esta separacion de responsabilidades es el corazon del proyecto. Cada componente hace una cosa y la hace bien. Cada punto que pidieron evaluar tiene su columna en esta tabla con la evidencia ejecutable."
3. **Cierre:** "El siguiente slide aterriza esto en arquitectura concreta: que servicios usamos y como se hablan entre si."

**Respuesta preparada:** "La frase 'LDAP autentica, OwnCloud autoriza' viene de una de las preguntas que hicimos por correo. Confirmada explicitamente. Eso simplifica el flujo y mantiene cada pieza con responsabilidad clara."

---

**Slide 3 de 24** | **Presentador:** Salgado Miranda Jorge | **Tiempo:** 45 segundos

# Arquitectura general

**Seis servicios en Docker Compose:**

| Servicio | Imagen | Rol |
|---|---|---|
| OpenLDAP | `osixia/openldap:1.5.0` | Directorio de usuarios + LDAPS |
| privacyIDEA | Imagen propia, version 3.10.2 | Servidor de tokens OTP |
| OwnCloud | `owncloud/server:10.15.3` | Portal web + permisos + cifrado |
| MariaDB | `mariadb:10.11` | Base de datos de OwnCloud |
| Redis | `redis:7` | Cache y locking de OwnCloud |
| Caddy | `caddy:2-alpine` | Terminador TLS hacia el usuario |

**Conexiones internas:** Caddy reenvia a OwnCloud por HTTPS. OwnCloud consulta LDAP por LDAPS y privacyIDEA por HTTPS interno. privacyIDEA tambien consulta LDAP por LDAPS.

**Lo que dice el presentador:**

1. **Apertura:** "Estos son los seis servicios que componen el stack. Cada uno tiene un proposito claro y un solo proposito."
2. **Sosten:** "Caddy expone el HTTPS publico al usuario. OwnCloud es la aplicacion que ve el usuario. OpenLDAP es la fuente unica de identidad para todos. privacyIDEA es servidor especializado en tokens, no IdP generalista. MariaDB y Redis son infraestructura de OwnCloud."
3. **Cierre:** "Con esta arquitectura cerrada, el siguiente slide muestra el cumplimiento contra los cinco puntos del PDF."

**Respuesta preparada:** "Si preguntan por que Compose y no Kubernetes: para seis servicios sin necesidad de distribucion, Compose es la herramienta correcta. Kubernetes seria sobre-ingenieria. Si esto fuera produccion multi-nodo, ahi si valdria la pena."

---

**Slide 4 de 24** | **Presentador:** Salgado Miranda Jorge | **Tiempo:** 45 segundos

# Cumplimiento contra el PDF

**Los cinco puntos evaluables, cerrados con scripts reproducibles:**

| Punto evaluable | Evidencia ejecutable |
|---|---|
| Alta de usuarios LDAP | `./scripts/ldap-verify.sh` confirma 6 usuarios humanos y LDAPS |
| Integracion privacyIDEA | `./scripts/privacyidea-verify.sh` confirma resolver `sia-ldap` y realm `sia` |
| Emision de OTP en app movil | `./scripts/privacyidea-enroll-test-token.sh` genera URL `otpauth://` |
| Implementacion OwnCloud + 2FA | `./scripts/owncloud-verify.sh` confirma OwnCloud 10.15, LDAP, 2FA y cifrado |
| 2FA LDAP + OTP integrado | `./scripts/owncloud-login-verify.sh` ejecuta login web completo |
| Compartidos y cifrado | `./scripts/owncloud-share-verify.sh` valida share + lectura descifrada |

Adicionalmente: `./scripts/bootstrap.sh` ejecuta todas las fases en orden y termina con `Listo` si todo paso.

**Lo que dice el presentador:**

1. **Apertura:** "Esta tabla mapea cada punto que pidieron evaluar a un script reproducible que lo demuestra."
2. **Sosten:** "La diferencia entre un README que dice 'funciona' y un script `verify` ejecutable es que el segundo no puede mentir. Cada punto se cierra con codigo que ustedes pueden correr en su laptop y obtener `Todo OK` o `ERROR` con detalle. No hay zona gris."
3. **Cierre:** "Con esto cierro la apertura. Le paso la palabra a Arely para que explique el marco conceptual de doble factor que es el fundamento de lo que sigue."

**Respuesta preparada:** "Si preguntan por que la auditoria no esta en la tabla: porque confirmaron por correo que la cuarta capa no se evalua. Se mantiene documentada en `docs/auditoria.md` como complemento academico para no romper el marco de cuatro capas."

---

**Slide 5 de 24** | **Presentador:** Olvera Gonzalez Arely | **Tiempo:** 45 segundos

# Las cuatro capas del control de acceso

| Capa | Pregunta | En este proyecto |
|---|---|---|
| Identificacion | Quien dice ser el usuario? | OpenLDAP almacena UIDs unicos |
| Autenticacion | Puede demostrar que es quien dice ser? | Password LDAP + OTP TOTP |
| Autorizacion | Que tiene permitido hacer? | OwnCloud decide permisos y compartidos |
| Auditoria | Quien hizo que y cuando? | Logs de los componentes (complemento no evaluable) |

La asignatura lo presento como un marco completo. **Omitir cualquiera deja huecos explotables.**

**Lo que dice el presentador:**

1. **Apertura:** "Gracias Jorge. Antes de entrar a la implementacion, recordemos el marco de las cuatro capas."
2. **Sosten:** "La autenticacion fuerte requiere combinar factores de categorias distintas. Algo que el usuario sabe, algo que tiene, algo que es. En este proyecto usamos los dos primeros: contrasena y token OTP. La autorizacion vive en una capa diferente, OwnCloud, no en LDAP."
3. **Cierre:** "El siguiente slide entra al detalle de los tres factores y por que dos contrasenas no cuentan como 2FA."

**Respuesta preparada:** "La cuarta capa, auditoria, esta documentada con scripts y logs reales en `docs/auditoria.md` aunque no es evaluable. Cubrimos el marco completo para mantener consistencia con lo presentado en clase."

---

**Slide 6 de 24** | **Presentador:** Olvera Gonzalez Arely | **Tiempo:** 45 segundos

# Tres factores de autenticacion

| Factor | Definicion | Ejemplos |
|---|---|---|
| **Conocimiento** | Algo que el usuario sabe | Contrasena, PIN, respuestas de seguridad |
| **Posesion** | Algo que el usuario tiene | Token OTP, llave fisica, telefono enrolado |
| **Inherencia** | Algo que el usuario es | Huella, rostro, iris |

**Dos contrasenas NO son 2FA.** Los factores tienen que ser de categorias distintas. En este proyecto usamos contrasena (conocimiento) + TOTP (posesion).

**Lo que dice el presentador:**

1. **Apertura:** "Los tres factores son los pilares de la autenticacion moderna. Cada uno aporta una garantia distinta."
2. **Sosten:** "Conocimiento es lo mas debil porque puede ser observado, filtrado o reusado en multiples sitios. Posesion exige al atacante tener acceso fisico al dispositivo del usuario, lo cual aumenta el costo del ataque drasticamente. La combinacion de ambos es 2FA real."
3. **Cierre:** "El siguiente slide compara las dos variantes principales de OTP, HOTP y TOTP, para explicar por que elegimos TOTP."

**Respuesta preparada:** "Si preguntan por inherencia: la descartamos porque requiere hardware adicional y el alcance era hacer 2FA reproducible solo con software. El principio sigue siendo el mismo: combinar dos categorias diferentes."

---

**Slide 7 de 24** | **Presentador:** Olvera Gonzalez Arely | **Tiempo:** 45 segundos

# HOTP vs TOTP

| Atributo | HOTP (RFC 4226) | TOTP (RFC 6238) |
|---|---|---|
| Contador | Numero entero incrementado por uso | Tiempo Unix dividido en ventanas de 30 segundos |
| Sincronizacion | Cliente y servidor mantienen contador | Cliente y servidor con reloj cercano |
| Apps compatibles | Algunas llaves fisicas | FreeOTP, Proton Authenticator, Google Authenticator |
| Algoritmo | HMAC-SHA1 con truncado dinamico | HMAC-SHA1 sobre `floor(unix_time / 30)` |

**Este proyecto usa TOTP.** Si el usuario falla un OTP, el contador no se desincroniza.

```
TOTP = truncate( HMAC-SHA1( secreto, floor(unix_time / 30) ) )
```

**Lo que dice el presentador:**

1. **Apertura:** "Los dos estandares vienen de la misma familia RFC. HOTP es la base, TOTP es la extension basada en tiempo."
2. **Sosten:** "HOTP usa un contador entero que cliente y servidor deben mantener sincronizado. TOTP usa el tiempo Unix dividido en ventanas de treinta segundos, lo que elimina el problema de sincronizacion explicita. Por eso TOTP es el estandar dominante en apps moviles."
3. **Cierre:** "La formula que ven en pantalla la implementamos en Python para validar localmente sin depender del telefono. El siguiente slide cierra el marco conceptual con la proteccion anti-replay."

**Respuesta preparada:** "Si preguntan por que SHA1 y no SHA256: SHA1 es el default del RFC y lo que todas las apps moviles soportan. SHA256 y SHA512 estan permitidos pero rompen compatibilidad. Es un trade-off entre fuerza criptografica y compatibilidad practica."

---

**Slide 8 de 24** | **Presentador:** Olvera Gonzalez Arely | **Tiempo:** 45 segundos

# Anti-replay y ventana de tiempo

privacyIDEA rechaza el mismo OTP dos veces dentro de la misma ventana de 30 segundos. Mensaje literal en el log:

```
wrong otp value. previous otp used again
```

**Que protege:** ataques de repeticion triviales. Si el atacante observa el codigo y lo intenta reusar en la misma ventana, el servidor lo detecta. Cuando la ventana cambia, el codigo anterior expira completamente.

**Validacion en el proyecto:** `./scripts/privacyidea-validate-otp.sh`.

**Lo que dice el presentador:**

1. **Apertura:** "La proteccion anti-replay del estandar previene exactamente este escenario: alguien observa el codigo y lo reusa rapido."
2. **Sosten:** "privacyIDEA mantiene cache de los OTP validados recientemente. Este mensaje de log es real, sacado de las pruebas. La ventana de treinta segundos es el default del RFC, suficiente para usabilidad pero corta para minimizar ventana de ataque."
3. **Cierre:** "Con esto cierro el marco conceptual. Le paso a Luis Ivan para que explique como diseamos el directorio LDAP que sostiene toda la identidad."

**Respuesta preparada:** "Si preguntan por la ventana de treinta segundos: es el default RFC. privacyIDEA permite ajustarla pero la dejamos en treinta porque es lo que las apps moviles esperan. Reducirla rompe compatibilidad."

---

**Slide 9 de 24** | **Presentador:** Lopez Segundo Luis Ivan | **Tiempo:** 45 segundos

# Estructura del arbol LDAP

**Base DN:** `dc=sia,dc=unam,dc=mx`

```
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
`-- ou=Servicios
    `-- cn=svc-owncloud
```

6 usuarios humanos separados por area. La cuenta de servicio vive aparte y no contamina el conteo humano.

**Lo que dice el presentador:**

1. **Apertura:** "Gracias Arely. La identidad de los usuarios vive en OpenLDAP. Este es el arbol que diseamos."
2. **Sosten:** "Base DN convencion DNS-style: `sia` es la abreviacion de la materia y `unam.edu.mx` es el sufijo institucional. Los seis usuarios humanos estan en dos OUs por area, Desarrollo y Seguridad. La cuenta de servicio que usan OwnCloud y privacyIDEA para hacer bind vive en `ou=Servicios`, separada."
3. **Cierre:** "Esta separacion fue clave para que el conteo de humanos no se contaminara, y la explico en el siguiente slide."

**Respuesta preparada:** "Si preguntan por la base DN academica: aunque sea laboratorio, mantener convencion DNS-style fue deliberado. El formato es reusable y se entiende sin contexto adicional."

---

**Slide 10 de 24** | **Presentador:** Lopez Segundo Luis Ivan | **Tiempo:** 45 segundos

# Decisiones de diseno LDAP

| Decision | Por que |
|---|---|
| `uid` como atributo de login | Convencion LDAP simple y estable |
| 6 usuarios humanos | Permite probar dos areas sin ruido |
| `inetOrgPerson` para usuarios | Schema estandar para personas, suficiente sin login SSH |
| `svc-owncloud` separada en `ou=Servicios` | OwnCloud no usa `cn=admin`; mejor practica |
| ACL restrictiva en cuenta de servicio | Lee usuarios pero NO `userPassword` |
| LDAPS desde el primer arranque | Passwords y binds nunca en claro |
| Passwords `{SSHA}` en LDIF | No quedan en plano en el repositorio |

**Lo que dice el presentador:**

1. **Apertura:** "Cada decision tiene una razon documentada. No improvisamos."
2. **Sosten:** "La decision que mas trabajo nos dio fue separar la cuenta de servicio del arbol de usuarios humanos. La primera version la teniamos en la misma rama con `inetOrgPerson` y el filtro contaba siete personas. Reubicarla con `simpleSecurityObject` en `ou=Servicios` resolvio el problema sin agregar codigo, solo cambiando el modelo."
3. **Cierre:** "El siguiente slide muestra el contrato exacto que OwnCloud y privacyIDEA esperan de este directorio."

**Respuesta preparada:** "Si preguntan por que LDAPS y no STARTTLS: elegimos LDAPS por simplicidad. STARTTLS requiere primero conectar en plano y negociar TLS, lo que agrega un paso. Con LDAPS, la conexion es TLS desde el primer byte."

---

**Slide 11 de 24** | **Presentador:** Lopez Segundo Luis Ivan | **Tiempo:** 45 segundos

# Lo que OwnCloud y privacyIDEA piden

| Campo LDAP | Valor |
|---|---|
| Host LDAPS | `ldaps://openldap:636` |
| Base DN raiz | `dc=sia,dc=unam,dc=mx` |
| Base DN usuarios | `ou=Usuarios,dc=sia,dc=unam,dc=mx` |
| Bind DN servicio | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` |
| Filtro usuarios | `(objectClass=inetOrgPerson)` |
| Atributo de login | `uid` |

Los dos consumidores hablan el mismo protocolo y comparten la misma cuenta de servicio. **Un solo punto de configuracion para gestionar credenciales de servicio.**

**Lo que dice el presentador:**

1. **Apertura:** "OwnCloud y privacyIDEA hablan el mismo lenguaje LDAP y comparten la misma cuenta de servicio."
2. **Sosten:** "Esto significa que solo hay un lugar donde gestionar el password de `svc-owncloud`. Si rotamos esa credencial, lo hacemos en LDAP y en los dos consumidores. No hay forma de olvidar uno. Esta consolidacion fue otra decision consciente."
3. **Cierre:** "Para validar que toda esta configuracion funciona, el script de verificacion corre ocho chequeos automaticos."

**Respuesta preparada:** "Si preguntan por que `inetOrgPerson` y no `posixAccount`: posixAccount agrega campos para login SSH unix. En este proyecto los usuarios solo usan LDAP via aplicacion, no por SSH. inetOrgPerson es suficiente y mas limpio."

---

**Slide 12 de 24** | **Presentador:** Lopez Segundo Luis Ivan | **Tiempo:** 45 segundos

# Validacion automatica del directorio

```bash
./scripts/ldap-verify.sh
```

**Ocho chequeos ejecutables:**

1. Bind con admin funciona.
2. Hay exactamente 6 usuarios humanos.
3. La cuenta de servicio puede leer usuarios.
4. La cuenta de servicio NO puede leer `userPassword`.
5. Filtro `(objectClass=inetOrgPerson)` excluye la cuenta de servicio.
6. Credenciales invalidas se rechazan con err=49.
7. LDAPS responde en `localhost:6636`.
8. Certificado de LDAP es valido segun la CA local.

Si todo pasa: `Todo OK.`

**Lo que dice el presentador:**

1. **Apertura:** "El script `ldap-verify.sh` documenta el contrato del directorio y lo prueba con ocho chequeos concretos."
2. **Sosten:** "Lo mas importante no es solo que LDAP responde, sino que la ACL es restrictiva. El chequeo cuatro confirma que la cuenta de servicio NO puede leer `userPassword`, solo los demas atributos. Esto es minimo privilegio explicito y verificable."
3. **Cierre:** "Con la identidad cubierta, le paso a Mauricio para que explique como privacyIDEA gestiona el segundo factor sobre estos mismos usuarios."

**Respuesta preparada:** "Si preguntan que pasa si admin se equivoca con el password: el chequeo seis confirma que err=49 (invalid credentials) se devuelve, sin distinguir entre 'usuario no existe' y 'password incorrecto'. Sin leaks de informacion."

---

**Slide 13 de 24** | **Presentador:** Ferreira Rojas Mauricio | **Tiempo:** 45 segundos

# privacyIDEA como servidor de tokens

privacyIDEA **NO duplica usuarios.** Los lee del LDAP mediante:

| Concepto | Valor |
|---|---|
| Resolver | `sia-ldap` |
| URI | `ldaps://openldap:636` |
| Realm | `sia` |
| API | `https://localhost:8443` |
| Tipo de token | TOTP de 6 digitos cada 30 segundos |

**Fuente unica de verdad:** la identidad esta en LDAP, el token esta en privacyIDEA. Dar de baja en LDAP revoca tokens automaticamente.

**Lo que dice el presentador:**

1. **Apertura:** "Gracias Luis Ivan. privacyIDEA es el servidor de tokens, no duplica usuarios, los lee del mismo LDAP que acaban de explicar."
2. **Sosten:** "Es un patron de fuente unica de verdad: la identidad esta en LDAP, el token esta en privacyIDEA, y la relacion uno-a-uno entre usuario y token vive en privacyIDEA. Si dan de baja a un usuario en LDAP, privacyIDEA automaticamente deja de poder validar tokens para esa identidad. Sin pasos adicionales."
3. **Cierre:** "Veamos como se enrola un token desde cero."

**Respuesta preparada:** "Si preguntan por que privacyIDEA y no Keycloak: Keycloak es un IdP generalista. privacyIDEA es especialista en tokens (TOTP, HOTP, push, WebAuthn, llaves) y tiene integracion oficial con OwnCloud. Keycloak hubiera sido sobre-ingenieria."

---

**Slide 14 de 24** | **Presentador:** Ferreira Rojas Mauricio | **Tiempo:** 45 segundos

# Enrolamiento TOTP automatizado

El script `privacyidea-enroll-test-token.sh` automatiza el flujo:

1. Autentica al admin en privacyIDEA via `/auth`.
2. Borra token anterior del usuario si existe.
3. Crea token TOTP nuevo con `genkey=1` (clave generada en servidor).
4. Imprime URL `otpauth://` para escanear con FreeOTP o Proton Authenticator.
5. Calcula el TOTP en Python localmente.
6. Valida el codigo contra `/validate/check` para probar emision sin depender del telefono.

**Resultado:** enrolamiento como pieza reproducible que cualquiera puede ejecutar.

**Lo que dice el presentador:**

1. **Apertura:** "El enrolamiento vincula un usuario LDAP con un token TOTP especifico."
2. **Sosten:** "El script automatiza lo que normalmente se hace desde la UI. Las partes interesantes son los pasos 4 y 5: la URL `otpauth` puede escanearse como QR en el telefono real, y el paso 5 calcula el codigo en Python para validar emision sin telefono. Eso es clave para automatizacion y CI."
3. **Cierre:** "Veamos como se ve esa URL exactamente y que significa cada parametro."

**Respuesta preparada:** "Si preguntan por la seguridad del enrolamiento: el secreto se genera en el servidor y se entrega via HTTPS. La URL se escanea por QR. Para minimizar exposicion, el enrolamiento se hace en sesion autenticada de admin, sin que nadie mas vea la pantalla."

---

**Slide 15 de 24** | **Presentador:** Ferreira Rojas Mauricio | **Tiempo:** 45 segundos

# La URL otpauth

```
otpauth://totp/sia:usuario.desarrollo1?secret=BASE32&issuer=sia&algorithm=SHA1&digits=6&period=30
```

| Parametro | Significado |
|---|---|
| `totp` | Tipo de token (alternativa: `hotp`) |
| `sia` (issuer) | Realm de privacyIDEA |
| `usuario.desarrollo1` | UID LDAP |
| `secret` (BASE32) | Bytes del secreto compartido |
| `algorithm=SHA1` | Funcion HMAC |
| `digits=6` | Longitud del codigo |
| `period=30` | Ventana en segundos |

La app escanea el QR codificado con esta URL y guarda el secreto localmente.

**Lo que dice el presentador:**

1. **Apertura:** "El formato `otpauth://` es un estandar de facto adoptado por toda la industria de apps moviles."
2. **Sosten:** "Cada parametro tiene un proposito tecnico. El secreto va codificado en BASE32 para que sea seguro pasar por URL. El resto de parametros permiten que servidor y cliente se pongan de acuerdo sin asumir defaults. Esta URL se genera al enrolar y se descarta despues, no se persiste en logs."
3. **Cierre:** "Ahora veamos como OwnCloud usa esta infraestructura cuando un usuario hace login."

**Respuesta preparada:** "Si preguntan por que SHA1: es el default RFC y lo que todas las apps moviles soportan. SHA256 y SHA512 estan permitidos pero rompen compatibilidad con apps comunes. Trade-off entre fuerza criptografica y compatibilidad practica."

---

**Slide 16 de 24** | **Presentador:** Ferreira Rojas Mauricio | **Tiempo:** 45 segundos

# Validacion contra /validate/check

```bash
curl -k -X POST https://localhost:8443/validate/check \
  -d 'user=usuario.desarrollo1' \
  -d 'realm=sia' \
  -d 'pass=123456'
```

Respuesta exitosa:

```json
{
  "result": { "status": true, "value": true },
  "detail": { "message": "matching 1 tokens" }
}
```

| Caso | Respuesta |
|---|---|
| OTP valido | `value: true` |
| OTP invalido | `value: false` |
| Usuario no existe | `status: false` |

OwnCloud hace exactamente esta llamada via el plugin `twofactor_privacyidea`.

**Lo que dice el presentador:**

1. **Apertura:** "Cuando llega el momento de validar un codigo, todo se reduce a una sola llamada HTTPS."
2. **Sosten:** "El plugin de OwnCloud manda usuario, realm y el codigo. privacyIDEA responde con `value: true` si el codigo es valido para la ventana actual, o `false` en caso contrario. La estructura `result/status` distingue errores tecnicos de validacion fallida, una distincion importante para no devolver el mismo error en ambos casos."
3. **Cierre:** "Con esto cierro la parte de servidor de tokens. Le paso a Maria Elena para que explique como OwnCloud orquesta los dos factores y agrega la capa de autorizacion."

**Respuesta preparada:** "Si preguntan por `-k`: en laboratorio usamos CA local autofirmada. En produccion `-k` se reemplazaria con `--cacert /ruta/ca.crt` apuntando a la CA corporativa. Lo dejamos visible para mostrar que estamos conscientes de la decision."

---

**Slide 17 de 24** | **Presentador:** Rufino Lopez Maria Elena | **Tiempo:** 45 segundos

# OwnCloud como punto de control

| Funcion | Mecanismo |
|---|---|
| Resolucion de usuarios | App `user_ldap` por LDAPS |
| Primer factor (password) | Bind contra OpenLDAP |
| Segundo factor (OTP) | App `twofactor_privacyidea` a `/validate/check` |
| Autorizacion | Permisos por carpeta + OCS Sharing API |
| Cifrado en disco | Server Side Encryption con master key |

**Mensaje clave:** LDAP autentica, OwnCloud autoriza. Confirmado por correo con el profesor.

**Lo que dice el presentador:**

1. **Apertura:** "Gracias Mauricio. OwnCloud es la pieza visible para el usuario, la que orquesta todo lo que se ha explicado."
2. **Sosten:** "OwnCloud no implementa 2FA por si solo. Tiene un sistema de plugins y `twofactor_privacyidea` es uno oficial que delega completamente la validacion del segundo factor al servidor de tokens. Esta separacion sigue el principio de responsabilidad unica: cada componente hace lo que sabe hacer mejor."
3. **Cierre:** "Veamos el flujo de login paso a paso para entender como se compone todo esto."

**Respuesta preparada:** "Si preguntan por que OwnCloud 10 y no OCIS: el plugin twofactor_privacyidea aun no esta portado a OCIS. Hicimos la eleccion deliberada de usar la version mas madura del ecosistema para garantia de funcionamiento."

---

**Slide 18 de 24** | **Presentador:** Rufino Lopez Maria Elena | **Tiempo:** 45 segundos

# Flujo de login 2FA paso a paso

1. Usuario entra a `https://localhost:9443`.
2. Caddy termina TLS y reenvia a OwnCloud.
3. Usuario escribe `uid` + password.
4. OwnCloud hace bind LDAPS contra OpenLDAP.
5. Si el password es valido, OwnCloud pide segundo factor.
6. Usuario abre la app TOTP y copia el codigo actual.
7. OwnCloud manda el codigo a privacyIDEA via `/validate/check`.
8. Si privacyIDEA acepta, OwnCloud abre la sesion y la vista de archivos.

La cuenta local `admin` queda excluida (`piexclude=1`, `piexcludegroups=admin`) porque no existe en el realm LDAP.

**Lo que dice el presentador:**

1. **Apertura:** "El flujo de login compone lo que vimos en slides anteriores en una secuencia ordenada."
2. **Sosten:** "Cada paso requiere que el anterior haya sido exitoso. Si el password LDAP falla en el paso 4, nunca se llega a pedir OTP. Eso evita oraculos donde un atacante podria inferir si un usuario existe basandose en si le piden segundo factor. La cuenta admin local esta excluida porque no existe en el realm LDAP, sin esa exclusion el plugin la bloquearia."
3. **Cierre:** "Veamos ahora como los archivos se almacenan cifrados en disco."

**Respuesta preparada:** "Si preguntan por la cuenta admin: admin es local de OwnCloud para mantenimiento. En produccion se restringiria con MFA basado en llaves fisicas. Excluirla del realm LDAP es concesion academica deliberada y documentada."

---

**Slide 19 de 24** | **Presentador:** Rufino Lopez Maria Elena | **Tiempo:** 45 segundos

# Cifrado de archivos en disco

OwnCloud activa Server Side Encryption con master key. El archivo en el volumen Docker se ve asi:

```
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
[bloque cifrado AES-256-CTR]
```

La cabecera `HBEGIN` documenta modulo y algoritmo. **Prueba canonica de cifrado activo.**

**Limitacion declarada:** la master key vive en el mismo servidor que los datos. Protege contra robo de disco pero NO contra el administrador del servidor. En produccion se usaria cifrado extremo a extremo del lado cliente.

**Lo que dice el presentador:**

1. **Apertura:** "OwnCloud activa Server Side Encryption con master key. Esta cabecera es la prueba canonica de que el cifrado esta activo."
2. **Sosten:** "Si abren el archivo crudo en el volumen Docker, ven exactamente esto. El cifrado es transparente para usuarios autorizados via WebDAV pero el contenido nunca se almacena en claro. La limitacion declarada: la master key vive en el servidor, asi que esto protege contra robo de disco pero no contra el administrador del servidor."
3. **Cierre:** "El ultimo slide de mi bloque cierra con la prueba de compartidos, que es el otro lado de la moneda: autorizacion."

**Respuesta preparada:** "Si preguntan por el cipher: AES-256-CTR es lo que OwnCloud usa por default. Modo CTR es streaming-friendly y permite acceso aleatorio sin descifrar todo. AES-256 es la longitud de clave estandar para datos en reposo."

---

**Slide 20 de 24** | **Presentador:** Rufino Lopez Maria Elena | **Tiempo:** 45 segundos

# Compartidos via OCS Sharing API

**Flujo probado de extremo a extremo:**

1. `usuario.desarrollo3` inicia sesion con LDAP + OTP.
2. Sube `demo-share.txt` por WebDAV.
3. OwnCloud lo guarda cifrado (HBEGIN visible en disco).
4. Crea share hacia `usuario.seguridad1` con POST a `/ocs/v2.php/apps/files_sharing/api/v1/shares`.
5. `usuario.seguridad1` inicia sesion con LDAP + OTP propio.
6. Descarga el archivo y lo lee **descifrado**.

Automatizado en `./scripts/owncloud-share-verify.sh`. Confirma que **la autorizacion vive en OwnCloud, no en LDAP**.

**Lo que dice el presentador:**

1. **Apertura:** "La autorizacion vive en OwnCloud, no en LDAP. El share es el ejemplo concreto."
2. **Sosten:** "El script ejecuta los seis pasos. Notese que el destinatario hace su propio login con LDAP + OTP, lo que prueba que 2FA aplica tambien para el receptor. La lectura descifrada al final es la prueba canonica de que autorizacion y cifrado funcionan juntos: el destinatario tiene autorizacion via share, asi que OwnCloud le descifra. Sin autorizacion, no hay descifrado."
3. **Cierre:** "Le paso a Esteban para que muestre las capturas reales de todo esto funcionando end-to-end."

**Respuesta preparada:** "Si preguntan por OCS Sharing API y por que via API en lugar de UI: para demostrar autorizacion programaticamente. Cualquier integrador externo (script de migracion, panel de admin, integracion con LMS) usaria esta API. Es mas defendible que un clic en la UI."

---

**Slide 21 de 24** | **Presentador:** Arellanes Conde Esteban | **Tiempo:** 45 segundos

# Docker Compose y bootstrap

```bash
./scripts/bootstrap.sh
```

**Esquema de servicios:**

```
openldap    -> healthcheck: ldapwhoami
privacyidea -> healthcheck: HTTPS /validate/check
owncloud    -> healthcheck: status.php
db          -> mariadb (mysqladmin ping)
redis       -> redis-cli ping
proxy       -> Caddy termina TLS publico
```

**Healthchecks reales** (LDAPS, HTTPS), no solo TCP. Compose arranca servicios en orden de **dependencias sanas**, no de contenedores encendidos.

**Lo que dice el presentador:**

1. **Apertura:** "Gracias Maria Elena. Todo lo anterior corre en Docker Compose, no en seis maquinas separadas."
2. **Sosten:** "Cada servicio tiene un healthcheck real. OpenLDAP usa `ldapwhoami`, OwnCloud usa `status.php` por HTTPS, MariaDB usa `mysqladmin ping`. Compose arranca los servicios en orden de dependencias sanas. Esto significa que si OpenLDAP no esta serving requests, OwnCloud no arranca hasta que lo este. El sistema se auto-coordina."
3. **Cierre:** "Los siguientes dos slides son capturas y comandos de la demo real funcionando."

**Respuesta preparada:** "Si preguntan por Compose y no Kubernetes: para seis servicios sin necesidad de distribucion, Compose es la herramienta correcta. Kubernetes seria sobre-ingenieria. Si esto fuera produccion multi-nodo, ahi si valdria la pena migrar."

---

**Slide 22 de 24** | **Presentador:** Arellanes Conde Esteban | **Tiempo:** 45 segundos

# Demo: login web LDAP + OTP

**Captura de referencia:** `docs/figuras/figura3.png` muestra la pantalla intermedia de OTP entre password y archivos.

**Pasos visibles:**

1. Navegador en `https://localhost:9443`.
2. Login con `usuario.desarrollo1` + password.
3. OwnCloud verifica contra OpenLDAP.
4. Si pasa, OwnCloud pide OTP.
5. App TOTP genera codigo de 6 digitos.
6. Usuario lo escribe.
7. OwnCloud valida contra privacyIDEA.
8. Si pasa, abre la vista de archivos.

Si falla cualquier paso: el usuario se queda en la pantalla actual sin avanzar.

**Lo que dice el presentador:**

1. **Apertura:** "Esta captura muestra el flujo de login real, la pantalla intermedia donde OwnCloud pide el segundo factor."
2. **Sosten:** "El usuario ya paso el primer factor de password LDAP, OwnCloud verifico contra OpenLDAP, y ahora estamos en el challenge OTP. Si la app TOTP genera codigo y el usuario lo escribe, OwnCloud lo manda a privacyIDEA. Si pasa, abre archivos. Si no pasa, se queda aqui sin pista de cual factor fallo, para no dar oraculo al atacante."
3. **Cierre:** "La siguiente captura muestra la evidencia tecnica del cifrado y del share descifrado por el destinatario."

**Respuesta preparada:** "Si preguntan por que no demo en vivo: por dos razones. Una, los tiempos son ajustados, dieciocho minutos no dan para tropiezos de demo. Dos, las capturas son del sistema real corriendo. Si quieren verlo despues, esta listo en la laptop."

---

**Slide 23 de 24** | **Presentador:** Arellanes Conde Esteban | **Tiempo:** 45 segundos

# Demo: cifrado en disco y compartido

**Comando de evidencia del cifrado:**

```bash
docker exec otpsec-owncloud-server head -c 80 \
  /mnt/data/files/usuario.desarrollo1/files/demo-profe.txt
```

**Salida real:**

```
HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND
```

**Prueba completa de share + descifrado por destinatario:**

```bash
./scripts/owncloud-share-verify.sh \
  usuario.desarrollo3 usuario.seguridad1
```

Salida final esperada:

```
OK: usuario.seguridad1 descifro y leyo el archivo compartido.
```

**Lo que dice el presentador:**

1. **Apertura:** "Estas son las pruebas tecnicas finales: cifrado en disco y autorizacion."
2. **Sosten:** "El comando `head -c 80` lee los primeros 80 bytes del archivo cifrado y muestra la cabecera HBEGIN que documenta el algoritmo AES-256-CTR. La misma cabecera la pueden ejecutar ustedes sobre cualquier archivo subido. El segundo comando ejecuta todo el flujo de share como una unidad de prueba: emisor, cifrado, compartido, destinatario con su propio 2FA, lectura descifrada. Sin autorizacion en OwnCloud, no hay descifrado."
3. **Cierre:** "Con esto cierro la parte de demo. Vamos al cierre y preguntas."

**Respuesta preparada:** "Si preguntan por que dos usuarios distintos: compartir conmigo mismo no prueba autorizacion. Con usuario A creando el archivo y usuario B leyendolo descifrado, demostramos que OwnCloud decide quien puede leer que. LDAP no autoriza, OwnCloud si."

---

**Slide 24 de 24** | **Presentador:** Arellanes Conde Esteban (cierre con apoyo del equipo) | **Tiempo:** 45 segundos

# Limitaciones honestas y preguntas

| Decision academica declarada | Para llevarlo a produccion |
|---|---|
| `.env` versionado en repo | Gestor de secretos (Vault, AWS Secrets Manager) |
| CA local autofirmada | CA publica (Let's Encrypt) o corporativa |
| Password compartido entre usuarios de demo | Password unico por usuario, rotacion, MFA recovery |
| Master key local | Cifrado extremo a extremo del lado cliente |
| Una instancia por servicio | HA por componente, backups, monitoreo |
| Sin SIEM, solo logs locales | Envio a Loki, Splunk o ELK |

Repositorio: `https://github.com/chochy2001/otp-secured-cloud`

**Estamos los seis listos para preguntas.**

**Lo que dice el presentador:**

1. **Apertura:** "Para cerrar, queremos dejar explicitas las limitaciones del proyecto."
2. **Sosten:** "Todo lo que hicimos esta documentado, incluyendo lo que NO es production-ready. `.env` con secretos versionado, CA local, password compartido, master key local, sin alta disponibilidad. Son decisiones academicas deliberadas, no descuidos. La columna derecha muestra que sustituiriamos en produccion. Saber donde estan los huecos es parte del aprendizaje del semestre."
3. **Cierre:** "Repositorio publico, codigo abierto, scripts reproducibles. Estamos los seis disponibles para preguntas sobre cualquier componente. Gracias profesor."

**Respuestas preparadas para preguntas probables del profesor:**

| Pregunta | Respuesta corta |
|---|---|
| Donde se autentica el password? | En OpenLDAP, via bind LDAPS. |
| Donde se valida el OTP? | En privacyIDEA, endpoint `/validate/check`. |
| Donde vive la autorizacion? | En OwnCloud, con permisos y OCS Sharing API. |
| La app TOTP se conecta al servidor? | No. Genera TOTP localmente a partir del secreto. |
| Que pasa si roban el password? | Sin OTP, OwnCloud no abre sesion. |
| Que pasa si cae privacyIDEA? | El login 2FA falla; en produccion se requeriria HA o politica break-glass. |
| El cifrado protege contra el admin del servidor? | No con master key local; requiere cifrado extremo a extremo. |
| Por que no sincronizar grupos LDAP? | Modelo confirmado por correo: LDAP autentica, OwnCloud autoriza. Simplifica y evita acoplar permisos. |
| Por que TOTP y no WebAuthn? | TOTP no requiere hardware adicional; WebAuthn seria el siguiente paso. |
| Por que OwnCloud 10 y no OCIS? | El plugin twofactor_privacyidea aun no esta portado a OCIS. |

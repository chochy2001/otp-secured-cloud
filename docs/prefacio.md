# Prefacio

Este prefacio precede al contenido técnico del entregable y responde a tres preguntas que un evaluador puede hacerse al abrir el documento: por qué abordar este problema, cómo decidimos cada pieza y qué construimos al final. Cierra con lo que aprendimos durante la implementación. El propósito es dar contexto narrativo antes de entrar al detalle técnico de las secciones numeradas.

## Por qué este proyecto

El control de acceso es uno de los pilares de la seguridad informática. La asignatura Seguridad Informática Avanzada lo presentó como un marco de cuatro capas (identificación, autenticación, autorización y auditoría) y enfatizó que omitir cualquiera deja huecos explotables. De estas cuatro, la autenticación es la que más atención pública recibe porque es la primera línea de defensa visible para el usuario: la pantalla de inicio de sesión.

La autenticación con un solo factor (usuario + contraseña) sigue siendo el vector de ataque dominante en violaciones de datos reportadas anualmente. La razón es estructural: una contraseña, por compleja que sea, es algo que el usuario sabe y por lo tanto algo que puede ser intercambiado, observado o filtrado sin que el usuario se dé cuenta. Phishing, keyloggers, brechas de bases de datos y reutilización de credenciales producen una superficie de ataque grande con bajo costo para el atacante. La industria identifica que el segundo factor (algo que el usuario tiene) reduce drásticamente el éxito de estos ataques al imponer al atacante la posesión física del dispositivo.

Frente a opciones de segundo factor disponibles (SMS, push notifications, llaves FIDO2/WebAuthn, OTP por software, OTP por hardware), el OTP basado en tiempo (TOTP) ofrece la mejor relación costo/beneficio para un escenario académico y para muchas organizaciones reales: no requiere infraestructura adicional del proveedor (no SMS, no servidores push), funciona offline en el teléfono del usuario, está estandarizado por RFC 6238, y es compatible con docenas de apps gratuitas. Por eso TOTP es el segundo factor de este proyecto.

Decidimos construir un servicio de almacenamiento porque ejercita las cuatro capas del control de acceso en un escenario tangible: usuarios autenticándose con dos factores, autorización por carpetas, cifrado del contenido en disco y bitácoras de cada acceso. Un servicio de archivos privados es más ilustrativo que, por ejemplo, una API pura, porque los archivos compartidos son objetos visibles que el evaluador puede crear, mover, compartir y descifrar durante una demo.

## Cómo decidimos cada pieza

Las siguientes ocho decisiones técnicas estructuran todo el resto del entregable. Cada una se documenta con la alternativa principal descartada y la razón de la elección.

| Decisión | Elección | Alternativas descartadas | Por qué |
|---|---|---|---|
| Plataforma de despliegue | Docker Compose | Máquinas virtuales, Kubernetes | Reproducibilidad inmediata, bajo costo para laboratorio, suficiente para un stack de 6 servicios sin necesidad de orquestación distribuida |
| Directorio de identidad | OpenLDAP en imagen `osixia/openldap:1.5.0` | Active Directory, FreeIPA, Authentik | Software libre, control total del esquema, no requiere licencia ni dominio Windows |
| Servidor de tokens OTP | privacyIDEA 3.10.2 | Authelia, Keycloak, Vault | Especializado en gestión de tokens (no es IdP generalista), integra con OwnCloud vía plugin oficial `twofactor_privacyidea`, soporta enrolamiento programático |
| Servicio de almacenamiento | OwnCloud Server 10.15.3 | OCIS (sucesor en Go), NextCloud | Madurez del ecosistema de plugins relevantes (`user_ldap`, `twofactor_privacyidea`), documentación extensa, encryption module probado |
| Algoritmo OTP | TOTP de 6 dígitos (RFC 6238) | HOTP, push notifications, WebAuthn | Estándar amplio, compatible con FreeOTP, Proton Authenticator, Google Authenticator y similares; no requiere conectividad permanente |
| Cifrado de archivos | Server Side Encryption con master key | E2E del lado cliente, sin cifrado | Soportado nativamente por OwnCloud, transparente para usuarios autorizados, ilustra cifrado en disco con verificación canónica vía cabecera `HBEGIN` |
| Modelo de autorización | LDAP autentica, OwnCloud autoriza | Sincronizar grupos LDAP a OwnCloud | El profesor confirmó este modelo por correo; simplifica el flujo, evita acoplar permisos al directorio, separa responsabilidades de identidad y autorización |
| Estrategia de validación | Verify-first (script `*-verify.sh` antes que `*-configure.sh`) | Solo configurar y asumir que funciona | Evita autoengaño sobre el estado del sistema; cada validación es ejecutable y reportable; cualquier integrante puede demostrar funcionamiento sin recordar comandos |

Estas decisiones se tomaron de forma incremental durante el primer mes del proyecto y se documentaron antes de tocar configuración para evitar retrabajo. Cuando hubo que mover OwnCloud a HTTPS por TLS, por ejemplo, ya estaba claro qué cambiaba en el árbol LDAP, en el resolver de privacyIDEA y en los certificados.

## Qué construimos al final

El entregable cubre los cinco puntos evaluables del PDF del profesor. La siguiente tabla mapea cada uno a la sección del documento que lo describe y al script del repositorio que lo demuestra de forma reproducible. Esta tabla permite al evaluador navegar la entrega desde el requisito hasta la evidencia sin tener que reconstruir el contexto.

| Punto evaluable (PDF del profesor) | Sección de este documento | Evidencia ejecutable |
|---|---|---|
| Alta de usuarios en LDAP | "Diseño del árbol LDAP" | `./scripts/ldap-verify.sh` confirma 6 usuarios humanos, cuenta de servicio separada y LDAPS |
| Integración con privacyIDEA | "Arquitectura del sistema" y "Memoria técnica" | `./scripts/privacyidea-verify.sh` confirma resolver `sia-ldap` y realm `sia` |
| Emisión de OTP en app móvil | "Conceptos básicos" y "Memoria técnica" | `./scripts/privacyidea-enroll-test-token.sh` genera URL `otpauth://` lista para FreeOTP o Proton Authenticator |
| Implementación de OwnCloud | "Arquitectura del sistema" y "Memoria técnica" | `./scripts/owncloud-verify.sh` confirma OwnCloud 10.15, LDAP integrado, plugin 2FA y cifrado activo |
| Integración 2FA LDAP + OTP | "Memoria técnica" (todas las subsecciones) | `./scripts/owncloud-login-verify.sh usuario.desarrollo2` ejecuta el login web completo con primer y segundo factor |
| Autorización y cifrado de archivos compartidos | "Memoria técnica" (subsección shares) | `./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1` valida share y lectura descifrada por destinatario |

Adicionalmente, el comando `./scripts/bootstrap.sh` desde un clon limpio del repositorio ejecuta todas las fases en orden (generación de certificados, build, levantamiento, configuración, pruebas end-to-end) y termina con el mensaje `Listo` si todo pasó. Es la forma más directa de validar reproducibilidad sin memorizar comandos.

La cuarta capa de control de acceso, auditoría, queda documentada en `docs/auditoria.md` y automatizable con `./scripts/audit-capture.sh` como complemento académico conforme al marco conceptual presentado en la asignatura. Se incluye en el repositorio para no dejar incompleto el marco de cuatro capas, aun cuando la evaluación del proyecto se concentra en identificación, autenticación y autorización.

## Lo que aprendimos durante la implementación

Las siguientes seis decisiones se revisaron durante la construcción del laboratorio. Documentarlas explícitamente sirve a quien lea el entregable para entender que el diseño final no es el primer borrador sino el resultado de iteración contra el comportamiento real del software.

**1. La cuenta de servicio LDAP debe estar separada del árbol de usuarios humanos.** En la primera iteración la cuenta `svc-owncloud` vivía en la misma rama que los usuarios. El conteo de "usuarios humanos" devolvía 7 en lugar de 6 porque el filtro `(objectClass=inetOrgPerson)` la incluía. La solución fue moverla a `ou=Servicios` con `objectClass=simpleSecurityObject` + `organizationalRole`, que no coincide con el filtro humano.

**2. TLS LDAPS debe configurarse desde el primer arranque.** Inicialmente el directorio se levantaba sin LDAPS y se pretendía agregarlo después. Esto requirió re-importar LDIFs, regenerar certificados y reconfigurar privacyIDEA y OwnCloud. La lección: si la decisión arquitectónica es "TLS en todos los canales", se materializa desde el primer LDIF.

**3. El plugin `twofactor_privacyidea` requiere excluir al usuario admin local.** OwnCloud tiene una cuenta `admin` local que no existe en el realm LDAP `sia`. Sin excluirla con `piexclude=1` y `piexcludegroups=admin`, el plugin intentaba validar OTP para una cuenta sin token y bloqueaba el acceso de mantenimiento. La configuración correcta permite operar admin con password simple pero exige OTP para todos los usuarios LDAP.

**4. Los healthchecks de Docker deben usar protocolos reales.** El primer compose usaba `nc -z` (verificación TCP). Esto pasaba aunque el servicio LDAP no estuviera serving requests. La solución fue usar `ldapwhoami -H ldaps://...` para LDAP, `curl -fkSs https://.../status.php` para OwnCloud y similares. El compose ahora arranca servicios cuando dependencias están realmente sanas, no solo cuando el contenedor encendió.

**5. La cabecera `HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND` es la prueba canónica de cifrado en disco.** Inicialmente se intentaba demostrar cifrado leyendo el archivo y observando que no era el contenido original. La cabecera explícita es más concreta para evaluación: el formato es del módulo de cifrado de OwnCloud y la presencia de `cipher:AES-256-CTR` documenta el algoritmo exacto sin ambigüedad.

**6. La OCS Sharing API de OwnCloud rechaza Basic Auth cuando 2FA está activo.** El script de prueba de compartidos fallaba con error 401 usando autenticación básica. La razón es de diseño: si una cuenta requiere 2FA, basic auth no puede satisfacerlo en una sola petición. La solución fue obtener una cookie de sesión vía login interactivo (POST a `/index.php/login` con password + segundo POST con OTP) y usar esa cookie para llamar a `/ocs/v2.php/apps/files_sharing/api/v1/shares`. Esto refleja cómo funcionaría un cliente web real.

Estas son seis decisiones representativas; el repositorio contiene más decisiones menores documentadas en commits y en `docs/memoria-tecnica.md`. El propósito de listarlas en el prefacio es mostrar que el diseño final tiene historia y que las elecciones se hicieron con razón, no por accidente.

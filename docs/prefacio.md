# Prefacio

Este prefacio precede al contenido tecnico del entregable y responde a tres preguntas que un evaluador puede hacerse al abrir el documento: por que abordar este problema, como decidimos cada pieza y que construimos al final. Cierra con lo que aprendimos durante la implementacion. El proposito es dar contexto narrativo antes de entrar al detalle tecnico de las secciones numeradas.

## Por que este proyecto

El control de acceso es uno de los pilares de la seguridad informatica. La asignatura Seguridad Informatica Avanzada lo presento como un marco de cuatro capas (identificacion, autenticacion, autorizacion y auditoria) y enfatizo que omitir cualquiera deja huecos explotables. De estas cuatro, la autenticacion es la que mas atencion publica recibe porque es la primera linea de defensa visible para el usuario: la pantalla de inicio de sesion.

La autenticacion con un solo factor (usuario + contrasena) sigue siendo el vector de ataque dominante en violaciones de datos reportadas anualmente. La razon es estructural: una contrasena, por compleja que sea, es algo que el usuario sabe y por lo tanto algo que puede ser intercambiado, observado o filtrado sin que el usuario se de cuenta. Phishing, keyloggers, brechas de bases de datos y reutilizacion de credenciales producen una superficie de ataque grande con bajo costo para el atacante. La industria identifica que el segundo factor (algo que el usuario tiene) reduce drasticamente el exito de estos ataques al imponer al atacante la posesion fisica del dispositivo.

Frente a opciones de segundo factor disponibles (SMS, push notifications, llaves FIDO2/WebAuthn, OTP por software, OTP por hardware), el OTP basado en tiempo (TOTP) ofrece la mejor relacion costo/beneficio para un escenario academico y para muchas organizaciones reales: no requiere infraestructura adicional del proveedor (no SMS, no servidores push), funciona offline en el telefono del usuario, esta estandarizado por RFC 6238, y es compatible con docenas de apps gratuitas. Por eso TOTP es el segundo factor de este proyecto.

Decidimos construir un servicio de almacenamiento porque ejercita las cuatro capas del control de acceso en un escenario tangible: usuarios autenticandose con dos factores, autorizacion por carpetas, cifrado del contenido en disco y bitacoras de cada acceso. Un servicio de archivos privados es mas ilustrativo que, por ejemplo, una API pura, porque los archivos compartidos son objetos visibles que el evaluador puede crear, mover, compartir y descifrar durante una demo.

## Como decidimos cada pieza

Las siguientes ocho decisiones tecnicas estructuran todo el resto del entregable. Cada una se documenta con la alternativa principal descartada y la razon de la eleccion.

| Decision | Eleccion | Alternativas descartadas | Por que |
|---|---|---|---|
| Plataforma de despliegue | Docker Compose | Maquinas virtuales, Kubernetes | Reproducibilidad inmediata, bajo costo para laboratorio, suficiente para un stack de 6 servicios sin necesidad de orquestacion distribuida |
| Directorio de identidad | OpenLDAP en imagen `osixia/openldap:1.5.0` | Active Directory, FreeIPA, Authentik | Software libre, control total del esquema, no requiere licencia ni dominio Windows |
| Servidor de tokens OTP | privacyIDEA 3.10.2 | Authelia, Keycloak, Vault | Especializado en gestion de tokens (no es IdP generalista), integra con OwnCloud via plugin oficial `twofactor_privacyidea`, soporta enrolamiento programatico |
| Servicio de almacenamiento | OwnCloud Server 10.15.3 | OCIS (sucesor en Go), NextCloud | Madurez del ecosistema de plugins relevantes (`user_ldap`, `twofactor_privacyidea`), documentacion extensa, encryption module probado |
| Algoritmo OTP | TOTP de 6 digitos (RFC 6238) | HOTP, push notifications, WebAuthn | Estandar amplio, compatible con FreeOTP, Proton Authenticator, Google Authenticator y similares; no requiere conectividad permanente |
| Cifrado de archivos | Server Side Encryption con master key | E2E del lado cliente, sin cifrado | Soportado nativamente por OwnCloud, transparente para usuarios autorizados, ilustra cifrado en disco con verificacion canonica via cabecera `HBEGIN` |
| Modelo de autorizacion | LDAP autentica, OwnCloud autoriza | Sincronizar grupos LDAP a OwnCloud | El profesor confirmo este modelo por correo; simplifica el flujo, evita acoplar permisos al directorio, separa responsabilidades de identidad y autorizacion |
| Estrategia de validacion | Verify-first (script `*-verify.sh` antes que `*-configure.sh`) | Solo configurar y asumir que funciona | Evita auto-engano sobre el estado del sistema; cada validacion es ejecutable y reportable; cualquier integrante puede demostrar funcionamiento sin recordar comandos |

Estas decisiones se tomaron de forma incremental durante el primer mes del proyecto y se documentaron antes de tocar configuracion para evitar retrabajo. Cuando hubo que mover OwnCloud a HTTPS por TLS, por ejemplo, ya estaba claro que cambiaba en el arbol LDAP, en el resolver de privacyIDEA y en los certificados.

## Que construimos al final

El entregable cubre los cinco puntos evaluables del PDF del profesor. La siguiente tabla mapea cada uno a la seccion del documento que lo describe y al script del repositorio que lo demuestra de forma reproducible. Esta tabla permite al evaluador navegar la entrega desde el requisito hasta la evidencia sin tener que reconstruir el contexto.

| Punto evaluable (PDF del profesor) | Seccion de este documento | Evidencia ejecutable |
|---|---|---|
| Alta de usuarios en LDAP | "Diseno del arbol LDAP" | `./scripts/ldap-verify.sh` confirma 6 usuarios humanos, cuenta de servicio separada y LDAPS |
| Integracion con privacyIDEA | "Arquitectura del sistema" y "Memoria tecnica" | `./scripts/privacyidea-verify.sh` confirma resolver `sia-ldap` y realm `sia` |
| Emision de OTP en app movil | "Conceptos basicos" y "Memoria tecnica" | `./scripts/privacyidea-enroll-test-token.sh` genera URL `otpauth://` lista para FreeOTP o Proton Authenticator |
| Implementacion de OwnCloud | "Arquitectura del sistema" y "Memoria tecnica" | `./scripts/owncloud-verify.sh` confirma OwnCloud 10.15, LDAP integrado, plugin 2FA y cifrado activo |
| Integracion 2FA LDAP + OTP | "Memoria tecnica" (todas las subsecciones) | `./scripts/owncloud-login-verify.sh usuario.desarrollo2` ejecuta el login web completo con primer y segundo factor |
| Autorizacion y cifrado de archivos compartidos | "Memoria tecnica" (subseccion shares) | `./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1` valida share y lectura descifrada por destinatario |

Adicionalmente, el comando `./scripts/bootstrap.sh` desde un clon limpio del repositorio ejecuta todas las fases en orden (generacion de certificados, build, levantamiento, configuracion, pruebas end-to-end) y termina con el mensaje `Listo` si todo paso. Es la forma mas directa de validar reproducibilidad sin memorizar comandos.

La cuarta capa de control de acceso, auditoria, queda documentada en `docs/auditoria.md` y automatizable con `./scripts/audit-capture.sh` como complemento academico conforme al marco conceptual presentado en la asignatura. Se incluye en el repositorio para no dejar incompleto el marco de cuatro capas, aun cuando la evaluacion del proyecto se concentra en identificacion, autenticacion y autorizacion.

## Lo que aprendimos durante la implementacion

Las siguientes seis decisiones se revisaron durante la construccion del laboratorio. Documentarlas explicitamente sirve a quien lea el entregable para entender que el diseno final no es el primer borrador sino el resultado de iteracion contra el comportamiento real del software.

**1. La cuenta de servicio LDAP debe estar separada del arbol de usuarios humanos.** En la primera iteracion la cuenta `svc-owncloud` vivia en la misma rama que los usuarios. El conteo de "usuarios humanos" devolvia 7 en lugar de 6 porque el filtro `(objectClass=inetOrgPerson)` la incluia. La solucion fue moverla a `ou=Servicios` con `objectClass=simpleSecurityObject` + `organizationalRole`, que no coincide con el filtro humano.

**2. TLS LDAPS debe configurarse desde el primer arranque.** Inicialmente el directorio se levantaba sin LDAPS y se pretendia agregarlo despues. Esto requirio re-importar LDIFs, regenerar certificados y reconfigurar privacyIDEA y OwnCloud. La leccion: si la decision arquitectonica es "TLS en todos los canales", se materializa desde el primer LDIF.

**3. El plugin `twofactor_privacyidea` requiere excluir al usuario admin local.** OwnCloud tiene una cuenta `admin` local que no existe en el realm LDAP `sia`. Sin excluirla con `piexclude=1` y `piexcludegroups=admin`, el plugin intentaba validar OTP para una cuenta sin token y bloqueaba el acceso de mantenimiento. La configuracion correcta permite operar admin con password simple pero exige OTP para todos los usuarios LDAP.

**4. Los healthchecks de Docker deben usar protocolos reales.** El primer compose usaba `nc -z` (verificacion TCP). Esto pasaba aunque el servicio LDAP no estuviera serving requests. La solucion fue usar `ldapwhoami -H ldaps://...` para LDAP, `curl -fkSs https://.../status.php` para OwnCloud y similares. El compose ahora arranca servicios cuando dependencias estan realmente sanas, no solo cuando el contenedor encendio.

**5. La cabecera `HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND` es la prueba canonica de cifrado en disco.** Inicialmente se intentaba demostrar cifrado leyendo el archivo y observando que no era el contenido original. La cabecera explicita es mas concreta para evaluacion: el formato es del modulo de cifrado de OwnCloud y la presencia de `cipher:AES-256-CTR` documenta el algoritmo exacto sin ambiguedad.

**6. La OCS Sharing API de OwnCloud rechaza Basic Auth cuando 2FA esta activo.** El script de prueba de compartidos fallaba con error 401 usando autenticacion basica. La razon es de diseno: si una cuenta requiere 2FA, basic auth no puede satisfacerlo en una sola peticion. La solucion fue obtener una cookie de sesion via login interactivo (POST a `/index.php/login` con password + segundo POST con OTP) y usar esa cookie para llamar a `/ocs/v2.php/apps/files_sharing/api/v1/shares`. Esto refleja como funcionaria un cliente web real.

Estas son seis decisiones representativas; el repositorio contiene mas decisiones menores documentadas en commits y en `docs/memoria-tecnica.md`. El proposito de listarlas en el prefacio es mostrar que el diseno final tiene historia y que las elecciones se hicieron con razon, no por accidente.

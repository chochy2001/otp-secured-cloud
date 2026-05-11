# Preguntas al profesor: respuestas y supuestos confirmados

Estado al día del commit. El PDF enviado al profesor se mantiene fuera del repositorio porque es material de consulta interna.

## Bloque 1: respuestas explícitas del profesor

El profesor contestó las cuatro preguntas que le quedaban abiertas. La respuesta literal y la implicación para el proyecto están abajo.

### 1. Alcance del cliente en la demostración

**Respuesta del profesor:** "Con cliente web es suficiente."

**Implicación:** se mantiene el flujo de demostración únicamente por navegador web sobre OwnCloud (`https://localhost:9443`). No se configuran *app passwords* ni se usan clientes de escritorio o móvil para la demo. El plugin `twofactor_privacyidea` queda como segundo factor exclusivamente para sesiones web.

### 2. Versión de OwnCloud

**Respuesta del profesor:** "La versión que gusten pero que funcione."

**Implicación:** se elige OwnCloud 10.15 Server (basado en PHP), que es la rama madura donde `user_ldap` y `twofactor_privacyidea` están ampliamente probados. La opción Infinite Scale (OCIS) queda descartada porque su camino de integración 2FA es distinto y menos documentado a la fecha.

### 3. Modelo de autorización

**Respuesta del profesor:** "La identificación y autenticación en LDAP, la autorización en el aplicativo (OwnCloud)."

**Implicación:** OpenLDAP queda con dos responsabilidades exclusivas (identificación con UIDs únicos y autenticación con contraseña), y privacyIDEA con el segundo factor. La autorización (qué carpetas puede leer, escribir o compartir cada usuario) se administra dentro de OwnCloud. No se sincronizan grupos LDAP con OwnCloud; los permisos por carpeta se definen en la interfaz de OwnCloud o por OCS Sharing API. Esta es la división que ya tenía el proyecto, así que no requiere cambios estructurales.

### 4. Auditoría como cuarta capa

**Respuesta del profesor:** "No revisaremos capa de auditoría."

**Implicación:** la auditoría queda fuera del alcance evaluado. El proyecto la mantiene como material complementario porque el propio profesor presentó en clase el marco de control de acceso de cuatro capas y la auditoría es la última. El script `scripts/audit-capture.sh` y el archivo `docs/auditoria.md` siguen disponibles para quien quiera leer la evidencia, y se mencionan brevemente en la presentación, pero no se les dedica peso de demostración. Las tres capas que sí se evalúan (identificación, autenticación, autorización) reciben la prioridad del guion y de la demo en vivo.

## Bloque 2: supuestos confirmados

El profesor pidió "documéntelos y que se tenga claridad de ellos". Esto es la versión consolidada de los supuestos con los que arrancamos la implementación. Cada uno está implementado y documentado en su archivo de referencia.

| ID | Supuesto | Estado | Referencia |
|---|---|---|---|
| a | Base DN raíz `dc=sia,dc=unam,dc=mx`. Dos OUs humanas (`Desarrollo` y `Seguridad`) bajo `ou=Usuarios`, tres usuarios cada una. `objectClass=inetOrgPerson` y atributo de inicio de sesión `uid`. | Implementado | [`arbol-ldap.md`](arbol-ldap.md) |
| b | Cuenta de servicio `cn=svc-owncloud,ou=Servicios,...` de solo lectura, separada de los usuarios humanos y con ACL específica que no permite leer `userPassword`. | Implementado | [`arbol-ldap.md`](arbol-ldap.md) y [`memoria-tecnica.md`](memoria-tecnica.md) sección 3 |
| c | privacyIDEA usa el mismo LDAP como *user resolver*. No mantiene base de usuarios propia. Resolver `sia-ldap`, realm `sia`, ambos por LDAPS contra la CA local. | Implementado | [`memoria-tecnica.md`](memoria-tecnica.md) sección 5 |
| d | Tokens TOTP (RFC 6238) generados desde FreeOTP, Proton Authenticator u otra app TOTP en el teléfono del usuario. | Implementado | [`manual-freeotp.md`](manual-freeotp.md) y [`memoria-tecnica.md`](memoria-tecnica.md) sección 5 |
| e | Cifrado del lado servidor en OwnCloud, modo *master key*, AES-256-CTR. Es el único modo que permite compartir archivos cifrados entre usuarios en OwnCloud 10. | Implementado | [`memoria-tecnica.md`](memoria-tecnica.md) sección 6, validado por `scripts/owncloud-share-verify.sh` |
| f | Usuarios extra para escenarios de error: el script `scripts/owncloud-login-verify.sh` permite probar el login de cualquier `usuario.desarrolloN` o `usuario.seguridadN`. Se reservan dos usuarios (uno por OU) para demos de OTP rechazado. | Cubierto sin necesidad de extras: los seis usuarios mínimos sirven tanto para casos válidos como para casos de error según el OTP que se ingrese | [`auditoria.md`](auditoria.md) sección 7 (login con OTP rechazado) |
| g | Demo local en la laptop del equipo proyectada al grupo. Snapshot del entorno y grabación del flujo completo como respaldo. | Procedimiento documentado, snapshot y grabación los hace el equipo antes del día | [`como-probar.md`](como-probar.md) sección 10 |

## Bloque 3: puntos confirmados en clase (referencia)

- Docker o máquinas virtuales son indistintos. Se usa Docker Compose con tres servicios principales (OpenLDAP, privacyIDEA, OwnCloud) más sus dependencias (MariaDB, Redis, Caddy).
- OpenLDAP 2.x aceptado. La imagen `osixia/openldap:1.5.0` usa OpenLDAP 2.4.x con el patch correspondiente, suficiente para los objetivos del proyecto.
- Certificados TLS autofirmados son aceptados. El proyecto genera una CA local con `scripts/generate-certs.sh` y firma tres certificados de servidor.
- Presentación de 30 minutos en total con participación de los seis integrantes. Distribución por bloque en [`guion-exposicion.md`](guion-exposicion.md).

## Cambios al alcance derivados de las respuestas

Solo la respuesta a la pregunta 4 alteró el alcance del proyecto. El resto confirmó lo que ya estaba en marcha.

| Antes (por precaución) | Después (con la respuesta) |
|---|---|
| La auditoría se trataba como una de las cuatro entregas técnicas y se le dedicaban 3 minutos del guion. | La auditoría queda como contexto académico complementario. El bloque del guion se redistribuye a cubrir con más detalle carpetas compartidas y la demo en vivo. |
| El guion equilibraba las cuatro capas. | El guion enfatiza identificación, autenticación y autorización (las tres capas que se evalúan). |
| `audit-capture.sh` se presentaba como entregable. | Se presenta como evidencia complementaria del marco conceptual de cuatro capas que el profesor expuso en clase. |

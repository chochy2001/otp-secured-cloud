# Preguntas abiertas al profesor

Estado al día del commit. El PDF enviado al profesor se mantiene fuera del repositorio porque es material de consulta interna.

## Sin respuesta del profesor

El profesor no contestó estas preguntas. Para no detener el proyecto, se avanza con los supuestos de la siguiente sección. Si el profesor pide otro alcance, se ajusta sobre la base funcional actual.

1. **Alcance del cliente en la demostración:** solo web, o también escritorio/móvil.
2. **Versión de OwnCloud:** 10 Server (PHP) o Infinite Scale (OCIS, Go).
3. **Modelo de autorización:** grupos LDAP sincronizados a OwnCloud, o permisos puros en OwnCloud.
4. **Auditoría en la demo:** bitácoras en vivo o descripción en el documento.

## Supuestos declarados (veto del profesor si no aplican)

a. Árbol LDAP `dc=sia,dc=unam,dc=mx` con OUs `Desarrollo`, `Seguridad`, `Servicios`; `objectClass=inetOrgPerson`; login por `uid`. Estado: **implementado**.

b. Cuenta de servicio `cn=svc-owncloud,ou=Servicios,...` de solo lectura. Estado: **implementado**.

c. PrivacyIDEA usa el mismo LDAP como *user resolver*, no mantiene BD propia.

d. Tokens TOTP (RFC 6238) desde FreeOTP.

e. Cifrado OwnCloud *Server Side Encryption* modo *master key* (AES-256).

f. Demo principal por navegador web. WebDAV se usa solo en scripts de verificación.

g. OwnCloud Server 10.15, MariaDB, Redis y Caddy TLS.

h. Demo local en laptop + snapshot + grabación de respaldo.

## Ya confirmados en clase

- Docker o VMs indistintamente; sugerencia 3 instancias Linux separadas.
- OpenLDAP 2.x aceptado.
- Certificados TLS autofirmados aceptados.
- Presentación de 30 minutos.

## Qué avanzar ahora

La base técnica ya está implementada. Lo que sigue no depende de la respuesta del profesor:

- Preparar carpetas y permisos de demo dentro de OwnCloud.
- Documentar bitácoras y casos de auditoría.
- Consolidar la memoria técnica final.
- Preparar guion, slides, snapshot y grabación de respaldo.

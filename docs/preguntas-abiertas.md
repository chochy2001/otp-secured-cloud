# Preguntas abiertas al profesor

Estado al día del commit. El PDF enviado al profesor se mantiene fuera del repositorio porque es material de consulta interna.

## Requieren respuesta explícita

1. **Alcance del cliente en la demostración:** ¿solo web, o también escritorio/móvil? Bloquea decisiones de *app passwords* en OwnCloud.
2. **Versión de OwnCloud:** ¿10 Server (PHP) o Infinite Scale (OCIS, Go)? Bloquea la implementación de la capa de almacenamiento.
3. **Modelo de autorización:** ¿grupos LDAP sincronizados a OwnCloud, o permisos puros en OwnCloud? Bloquea el diseño de grupos en el árbol LDAP.
4. **Auditoría en la demo:** ¿mostrar bitácoras en vivo o solo describirlas en el documento?

## Supuestos declarados (veto del profesor si no aplican)

a. Árbol LDAP `dc=sia,dc=unam,dc=mx` con OUs `Desarrollo`, `Seguridad`, `Servicios`; `objectClass=inetOrgPerson`; login por `uid`. Estado: **implementado**.

b. Cuenta de servicio `cn=svc-owncloud,ou=Servicios,...` de solo lectura. Estado: **implementado**.

c. PrivacyIDEA usa el mismo LDAP como *user resolver*, no mantiene BD propia.

d. Tokens TOTP (RFC 6238) desde FreeOTP.

e. Cifrado OwnCloud *Server Side Encryption* modo *master key* (AES-256).

f. 1 a 2 usuarios extra fuera del mínimo de 6 para demostrar casos de error.

g. Demo local en laptop + snapshot + grabación de respaldo.

## Ya confirmados en clase

- Docker o VMs indistintamente; sugerencia 3 instancias Linux separadas.
- OpenLDAP 2.x aceptado.
- Certificados TLS autofirmados aceptados.
- Presentación de 30 minutos.

## Qué avanzar mientras llegan las respuestas

Todo lo anterior a OwnCloud se puede construir sin bloqueo:

- OpenLDAP con el árbol completo y los 6 usuarios.
- PrivacyIDEA con el *resolver* hacia LDAP y la capacidad de enrolar un token desde FreeOTP.
- CA del proyecto + certificados autofirmados.
- Documentación (conceptos básicos, árbol LDAP, arquitectura, glosario).

Las decisiones sobre OwnCloud esperan a las respuestas 1 a 4 para evitar retrabajo.

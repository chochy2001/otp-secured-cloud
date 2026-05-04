# Bibliografía

## Estándares y RFCs

1. M. Bellare, R. Canetti, H. Krawczyk. *HMAC: Keyed-Hashing for Message Authentication*. RFC 2104, IETF, febrero de 1997. https://www.rfc-editor.org/rfc/rfc2104
2. D. M'Raihi, M. Bellare, F. Hoornaert, D. Naccache, O. Ranen. *HOTP: An HMAC-Based One-Time Password Algorithm*. RFC 4226, IETF, diciembre de 2005. https://www.rfc-editor.org/rfc/rfc4226
3. D. M'Raihi, S. Machani, M. Pei, J. Rydell. *TOTP: Time-Based One-Time Password Algorithm*. RFC 6238, IETF, mayo de 2011. https://www.rfc-editor.org/rfc/rfc6238
4. K. Zeilenga. *Lightweight Directory Access Protocol (LDAP): Technical Specification Road Map*. RFC 4510, IETF, junio de 2006. https://www.rfc-editor.org/rfc/rfc4510
5. J. Sermersheim, ed. *Lightweight Directory Access Protocol (LDAP): The Protocol*. RFC 4511, IETF, junio de 2006. https://www.rfc-editor.org/rfc/rfc4511
6. M. Wahl, T. Howes, S. Kille. *Lightweight Directory Access Protocol (v3): UTF-8 String Representation of Distinguished Names*. RFC 4514, IETF, junio de 2006. https://www.rfc-editor.org/rfc/rfc4514
7. L. Dusseault, ed. *HTTP Extensions for Web Distributed Authoring and Versioning (WebDAV)*. RFC 4918, IETF, junio de 2007. https://www.rfc-editor.org/rfc/rfc4918
8. E. Rescorla. *The Transport Layer Security (TLS) Protocol Version 1.3*. RFC 8446, IETF, agosto de 2018. https://www.rfc-editor.org/rfc/rfc8446
9. R. Fielding, M. Nottingham, J. Reschke, eds. *HTTP Semantics*. RFC 9110, IETF, junio de 2022. https://www.rfc-editor.org/rfc/rfc9110

## Documentación oficial de los componentes

10. The OpenLDAP Project. *OpenLDAP Software 2.4 Administrator's Guide*. https://www.openldap.org/doc/admin24/. (La imagen `osixia/openldap:1.5.0` empaqueta `slapd 2.4.57+dfsg`; los conceptos del proyecto siguen siendo aplicables a las versiones 2.5 y 2.6 más recientes.)
11. NetKnights GmbH. *privacyIDEA Documentation*. https://privacyidea.readthedocs.io/
12. OwnCloud GmbH. *OwnCloud Server Administration Manual 10.x*. https://doc.owncloud.com/server/10.15/admin_manual/
13. OwnCloud GmbH. *Encryption Configuration*. https://doc.owncloud.com/server/10.15/admin_manual/configuration/files/encryption/
14. OwnCloud GmbH. *OCS Share API*. https://doc.owncloud.com/server/10.15/developer_manual/core/apis/ocs-share-api.html
15. NetKnights GmbH. *privacyIDEA OwnCloud Plugin: twofactor_privacyidea*. https://github.com/privacyidea/privacyidea-owncloud-app
16. The Caddy Authors. *Caddy v2 Documentation*. https://caddyserver.com/docs/
17. MariaDB Foundation. *MariaDB Server Documentation*. https://mariadb.com/kb/en/documentation/
18. Redis Ltd. *Redis Documentation*. https://redis.io/docs/

## Imágenes Docker utilizadas

19. Osixia. *osixia/openldap Docker image (Tag 1.5.0)*. https://hub.docker.com/r/osixia/openldap
20. OwnCloud GmbH. *owncloud/server Docker image (Tag 10.15)*. https://hub.docker.com/r/owncloud/server
21. Caddy. *caddy Docker image (Tag 2-alpine)*. https://hub.docker.com/_/caddy
22. MariaDB. *mariadb Docker image (Tag 10.11)*. https://hub.docker.com/_/mariadb
23. Redis. *redis Docker image (Tag 7-alpine)*. https://hub.docker.com/_/redis

## Marco conceptual de control de acceso

24. R. S. Sandhu, P. Samarati. *Access Control: Principles and Practice*. IEEE Communications Magazine, vol. 32, no. 9, septiembre de 1994.
25. NIST. *Special Publication 800-63B: Digital Identity Guidelines, Authentication and Lifecycle Management*. National Institute of Standards and Technology, junio de 2017 (revisado 2020). https://pages.nist.gov/800-63-3/sp800-63b.html
26. NIST. *Special Publication 800-92: Guide to Computer Security Log Management*. National Institute of Standards and Technology, septiembre de 2006. https://csrc.nist.gov/publications/detail/sp/800-92/final
27. OWASP Foundation. *Authentication Cheat Sheet*. https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
28. OWASP Foundation. *Logging Cheat Sheet*. https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html

## Notas para citar este entregable

Los archivos del repositorio se citan con su ruta relativa al raíz `otp-secured-cloud/`. Por ejemplo: `scripts/owncloud-share-verify.sh` o `docs/auditoria.md`. Si se necesita anclar una cita a una versión exacta del código, se acompaña con el SHA corto del commit (siete primeros caracteres) tomado de `git log --oneline`. La versión del entregable a imprimir corresponde al último commit en `main` antes de la fecha de exposición del 29 de mayo de 2026.

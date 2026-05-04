# Glosario de términos

Este glosario reúne los términos técnicos y los acrónimos que aparecen en el resto del documento. Las definiciones están redactadas para que se entiendan sin contexto previo, manteniendo precisión técnica.

## A

**ACL (Access Control List, lista de control de acceso).** Mecanismo que asocia, a cada recurso, una lista de identidades o roles con permisos específicos sobre ese recurso. En LDAP las ACLs viven en `slapd.conf` o `cn=config` y delimitan qué identidades pueden leer o escribir cada atributo de cada entrada del árbol.

**Auditoría.** Cuarta capa del control de acceso. Consiste en registrar de forma fehaciente los eventos relevantes (quién, qué, cuándo, desde dónde) para investigar incidentes a posteriori y para demostrar cumplimiento.

**Autenticación.** Segunda capa del control de acceso. Proceso por el cual una identidad demuestra ser quien dice ser. Se categoriza por factores: algo que el usuario *conoce* (contraseña, PIN), algo que *tiene* (token físico, OTP) y algo que *es* (biometría).

**Autorización.** Tercera capa del control de acceso. Determina qué acciones puede realizar una identidad ya autenticada sobre los recursos del sistema. Se implementa con ACLs, RBAC u otros modelos.

## B

**Base DN (Base Distinguished Name).** Punto de partida de búsquedas LDAP. En este proyecto, `dc=sia,dc=unam,dc=mx`. Tanto OwnCloud como privacyIDEA exigen el Base DN en su configuración de cliente LDAP.

**Bind.** Operación LDAP que autentica una conexión. Un bind anónimo (sin DN ni contraseña) habilita búsquedas limitadas. Un bind autenticado proporciona DN y contraseña.

**Bind DN.** DN que se usa para autenticar al cliente. En este proyecto, OwnCloud y privacyIDEA usan `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` para hacer bind y leer el árbol.

## C

**CA (Certificate Authority, autoridad certificadora).** Entidad que firma certificados X.509 que vinculan una clave pública a un sujeto. En este proyecto se usa una CA local generada con OpenSSL en `certs/ca.crt`. Los clientes deben confiar explícitamente en esta CA para que la verificación TLS pase.

**Caddy.** Servidor web de código abierto escrito en Go. En este proyecto actúa como terminador TLS delante de OwnCloud, publicando el puerto `9443` con el certificado `owncloud.crt` firmado por la CA local.

**Cifrado del lado servidor (Server Side Encryption).** Modo de cifrado en el que el servidor de almacenamiento cifra y descifra los archivos por cuenta del usuario. La llave puede ser por usuario, por archivo o maestra. En este proyecto, OwnCloud usa el módulo por defecto con llave maestra (`master key`), donde la llave la conoce el servidor pero los archivos en disco quedan cifrados.

## D

**DC (Domain Component).** Atributo LDAP usado para representar partes del dominio en una jerarquía. `dc=sia,dc=unam,dc=mx` se compone de tres DCs.

**Docker Compose.** Herramienta para definir y orquestar aplicaciones multi-contenedor mediante un archivo `docker-compose.yml`. En este proyecto define los servicios `openldap`, `privacyidea`, `owncloud-server`, `owncloud-db`, `owncloud-redis` y `owncloud-proxy`.

## F

**FreeOTP.** Aplicación móvil de código abierto, mantenida por Red Hat y disponible para Android e iOS, que genera códigos OTP. En este proyecto es la "algo que el usuario tiene" del segundo factor.

## H

**HOTP (HMAC-based One-Time Password, RFC 4226).** Algoritmo OTP basado en un contador. El servidor y el dispositivo comparten una semilla secreta y un contador; cada uso incrementa el contador en ambos lados. Si el dispositivo y el servidor pierden sincronización, hay que resincronizar.

**HTTPS (HTTP Secure).** Protocolo HTTP encapsulado en TLS. En este proyecto privacyIDEA expone HTTPS en `8443` y OwnCloud lo expone (terminado por Caddy) en `9443`.

## I

**IGA (Identity Governance and Administration).** Disciplina que cubre el ciclo de vida de identidades en una organización: alta, modificación, revisión periódica y baja. LDAP es uno de los pilares de IGA al centralizar la fuente de verdad de identidades.

## L

**LDAP (Lightweight Directory Access Protocol, RFC 4511).** Protocolo de acceso a un directorio jerárquico. Define operaciones como bind, search, add, modify y delete. En este proyecto se usa para almacenar usuarios y grupos.

**LDAPS (LDAP over SSL/TLS).** LDAP encapsulado en TLS desde el primer byte. Se publica tradicionalmente en el puerto `636`. En este proyecto se publica en `localhost:6636` (mapeado al `636` interno) porque el puerto `636` del host estaba ocupado por otro proceso al inicio del proyecto.

## M

**MFA (Multi-Factor Authentication).** Generalización de 2FA. Requiere combinar dos o más factores de distinta categoría (conocimiento, posesión, biometría). 2FA es un caso particular con exactamente dos factores.

## N

**NHI (Non-Human Identity, identidad no humana).** Cuenta usada por software (servicio, automatización, integración) para autenticarse contra otros sistemas. La cuenta de servicio `cn=svc-owncloud` en este proyecto es una NHI: la usan privacyIDEA y OwnCloud para hacer bind contra OpenLDAP, no la usa una persona.

## O

**OCS Sharing API (OwnCloud Sharing API).** Endpoint REST de OwnCloud para gestionar archivos y carpetas compartidas, en `/ocs/v1.php/apps/files_sharing/api/v1/shares`. Acepta parámetros de path, tipo de share, destinatario y permisos.

**OpenLDAP.** Implementación de software libre del protocolo LDAP. La imagen `osixia/openldap` empaqueta `slapd` con utilidades de bootstrap.

**OTP (One-Time Password).** Contraseña de un solo uso, generada por un algoritmo determinista a partir de una semilla compartida. Existen variantes basadas en contador (HOTP) y basadas en tiempo (TOTP).

**OU (Organizational Unit, unidad organizacional).** Componente del DN que agrupa entradas. En este proyecto las OUs `Desarrollo`, `Seguridad` y `Servicios` cuelgan de `ou=Usuarios` y de la raíz para separar usuarios humanos de cuentas de servicio.

**OwnCloud.** Suite de almacenamiento de archivos en la nube de código abierto, con cliente web y soporte para WebDAV, compartición y plugins. En este proyecto se usa OwnCloud Server 10.15.3.

## P

**privacyIDEA.** Servidor de tokens de código abierto escrito en Python que centraliza el ciclo de vida de los OTP, soporta resolvers contra LDAP/AD/SQL, expone una API REST y se integra con OwnCloud mediante el plugin `twofactor_privacyidea`.

## R

**RBAC (Role-Based Access Control, control de acceso basado en roles).** Modelo de autorización donde los permisos se asocian a roles y los usuarios reciben uno o más roles. Reduce la complejidad de mantener ACLs por usuario individual.

**Realm.** Concepto de privacyIDEA. Un realm agrupa uno o más resolvers y le da nombre lógico al conjunto. En este proyecto el realm se llama `sia` y agrupa al resolver `sia-ldap`.

**Resolver.** Concepto de privacyIDEA. Es la conexión a una fuente de identidades (LDAP, SQL, etc.). El resolver `sia-ldap` apunta a `ldaps://openldap:636` con la cuenta de servicio.

## S

**slapd.** Demonio del servidor OpenLDAP. Sus eventos relevantes (BIND, SEARCH, MODIFY, RESULT) se registran en stdout/stderr y se capturan con `docker logs otpsec-openldap`.

## T

**TLS (Transport Layer Security).** Protocolo criptográfico que cifra y autentica conexiones de red. Las versiones 1.2 y 1.3 son las que se consideran seguras al día de hoy. Reemplaza al obsoleto SSL.

**TOTP (Time-based One-Time Password, RFC 6238).** Variante de HOTP donde el contador es el tiempo dividido en ventanas de 30 segundos por defecto. Es el algoritmo OTP que generan FreeOTP, Google Authenticator y la mayoría de los apps móviles. Es el que usa este proyecto.

**Twofactor_privacyidea.** App de OwnCloud que delega el segundo factor al servidor privacyIDEA. Configura un endpoint HTTPS de privacyIDEA y un nombre de realm. OwnCloud, tras validar el primer factor LDAP, redirige al usuario al selector de challenge donde se ingresa el OTP que privacyIDEA valida.

## U

**uid (user identifier).** Atributo LDAP comúnmente usado como nombre de inicio de sesión. En este proyecto los usuarios humanos tienen `uid=usuario.desarrollo1`, `uid=usuario.seguridad2`, etc.

## W

**WebDAV (Web Distributed Authoring and Versioning, RFC 4918).** Extensión de HTTP que permite gestionar archivos remotos. OwnCloud expone WebDAV en `/remote.php/webdav`. Los scripts de validación del proyecto usan WebDAV para subir y descargar archivos sin pasar por la interfaz web.

## 2

**2FA (Two-Factor Authentication, autenticación de dos factores).** Caso particular de MFA con exactamente dos factores de categorías distintas. En este proyecto: contraseña LDAP (conocimiento) + OTP TOTP (posesión).

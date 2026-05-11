# Introducción

El presente documento describe el diseño, implementación y validación de un servicio de almacenamiento de información con autenticación de doble factor (2FA) por contraseñas de un solo uso (OTP), construido como entregable final de la asignatura Seguridad Informática Avanzada del semestre 2026-2 de la Facultad de Ingeniería de la UNAM.

## Motivación

El control de acceso es uno de los pilares de la seguridad informática y se compone de cuatro capas: identificación, autenticación, autorización y auditoría. La asignatura ha enfatizado que omitir cualquiera de las cuatro deja huecos explotables en sistemas reales. La autenticación con un único factor, típicamente usuario y contraseña, sigue siendo el ataque vector más común en violaciones de datos publicadas año tras año, por lo que la adopción de un segundo factor (algo que el usuario tiene) es una de las medidas más efectivas para reducir el riesgo de toma de cuentas.

Por otra parte, el almacenamiento de archivos con servicios en la nube es una necesidad cotidiana en organizaciones académicas y empresariales. La combinación de un servicio de almacenamiento con 2FA permite ejercitar las cuatro capas del control de acceso en un escenario tangible: usuarios autenticándose con dos factores, autorización por carpetas, cifrado del contenido y bitácoras de cada acceso.

## Alcance

Se construye un laboratorio académico autocontenido, basado en software libre, donde un servicio de almacenamiento estilo Dropbox autoaloja archivos por usuario y por grupo. El alta de usuarios se centraliza en un directorio LDAP, el segundo factor se gestiona con un servidor de tokens OTP, los archivos se cifran del lado servidor y los eventos de acceso se registran en bitácoras consultables.

El profesor confirmó por correo que la evaluación se concentra en las tres primeras capas del control de acceso (identificación, autenticación y autorización) y que la cuarta capa (auditoría) no será revisada. La auditoría se mantiene en este documento y en los scripts del proyecto como complemento académico para que el marco de cuatro capas que el propio profesor presentó en clase quede ilustrado de extremo a extremo.

El proyecto NO pretende producir un sistema productivo. Es material didáctico que prioriza la claridad pedagógica sobre la robustez. La sección "Aviso de seguridad" del README del repositorio enumera todas las decisiones académicas que serían inapropiadas en un entorno real (contraseñas compartidas en el repo, certificados autofirmados, sin alta disponibilidad, etc.).

## Tecnologías seleccionadas

| Componente | Software | Versión |
|---|---|---|
| Directorio de usuarios | OpenLDAP en imagen `osixia/openldap` | 1.5.0 (slapd 2.4.x) |
| Servicio OTP | privacyIDEA en imagen propia con Python | 3.10.2 |
| Aplicación móvil para el segundo factor | App TOTP (FreeOTP o Proton Authenticator) | Cliente del usuario |
| Servicio de almacenamiento | OwnCloud Server | 10.15.3 |
| Base de datos del almacenamiento | MariaDB | 10.11 |
| Caché del almacenamiento | Redis | 7 |
| Terminador TLS | Caddy | 2 (alpine) |
| Plataforma | Docker Engine y Docker Compose v2 | actual |

La justificación detallada de cada decisión está en `docs/arquitectura.md` y `docs/arbol-ldap.md`.

## Mapeo a las cuatro capas del control de acceso

| Capa | Componente del proyecto | Evaluable |
|---|---|---|
| Identificación | OpenLDAP centraliza el alta de usuarios con UIDs únicos en `dc=sia,dc=unam,dc=mx`. Las cuentas humanas viven en `ou=Usuarios` separadas por OU `Desarrollo` y `Seguridad`; las cuentas de servicio viven en `ou=Servicios`. | Sí |
| Autenticación | El primer factor es la contraseña LDAP (algo que el usuario conoce). El segundo factor es un OTP TOTP de 6 dígitos generado por FreeOTP, Proton Authenticator u otra app TOTP en el teléfono y validado por privacyIDEA (algo que el usuario tiene). OwnCloud orquesta los dos factores con su plugin `twofactor_privacyidea`. | Sí |
| Autorización | OwnCloud define permisos por carpeta y por usuario, sin sincronizar grupos LDAP. Los archivos compartidos definen lectura y escritura mediante la API OCS Sharing. Esta división (LDAP autentica, OwnCloud autoriza) la confirmó el profesor de forma explícita. | Sí |
| Auditoría | Cada componente registra eventos. OpenLDAP escribe a stdout/stderr capturable con `docker logs`. PrivacyIDEA escribe a `/var/log/privacyidea/privacyidea.log` y a stdout con uwsgi access logs. OwnCloud escribe JSON estructurado a `/mnt/data/files/owncloud.log`. El script `scripts/audit-capture.sh` automatiza la captura de los 8 eventos clave del flujo. | No (complemento académico) |

## Estructura del documento

El resto de este entregable está organizado así:

1. Conceptos básicos de 2FA y OTP. Define los términos clave (HOTP, TOTP, apps TOTP, etc.) que la implementación referencia.
2. Diseño del árbol LDAP. Explica las decisiones de base DN, OUs, objectClasses y la cuenta de servicio que conectan OwnCloud y privacyIDEA.
3. Arquitectura del sistema. Diagrama de la solución, flujos de petición y red.
4. Memoria técnica paso a paso. Cómo se instaló y configuró cada componente con scripts reproducibles. Incluye una sección final sobre auditoría como complemento académico no evaluable.
5. Conclusiones individuales y de equipo.
6. Glosario, bibliografía e índice de figuras.

Los archivos del repositorio se citan con su ruta relativa (`docs/`, `scripts/`, `compose/`, `ldap/`, `privacyidea/`, `owncloud/`, `certs/`).

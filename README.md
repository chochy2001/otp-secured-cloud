# otp-secured-cloud

Servicio de almacenamiento de información con doble factor de autenticación (2FA) vía OTP, construido con **OpenLDAP**, **PrivacyIDEA**, **FreeOTP** y **OwnCloud**.

Proyecto final de la materia **Seguridad Informática Avanzada** (SIA), Facultad de Ingeniería, UNAM, semestre 2026-2.

---

## ⚠️ Aviso importante de seguridad e implementación

Este repositorio es material **académico** para el curso SIA de la FI-UNAM. Se construyó con fines **didácticos** y prioriza la claridad pedagógica sobre la robustez que se exigiría a un sistema productivo.

Antes de reutilizar este código para cualquier cosa que no sea estudiar, considera estos puntos:

1. **El archivo `.env` con contraseñas se commitea a propósito.** Es una mala práctica reconocida: lo hacemos para que los integrantes del equipo y quien revise el proyecto puedan levantar el entorno sin intercambiar secretos por otro canal. En producción las credenciales deben estar fuera del repositorio (gestor de secretos, variables en CI, etc.).
2. **Las contraseñas por defecto son débiles y compartidas.** Todos los usuarios comparten una misma contraseña (`sia-user-2026`). En producción debería existir política de contraseñas, rotación, y contraseñas únicas por usuario.
3. **Los LDIFs almacenan `userPassword` en texto plano.** OpenLDAP las hashea al importar, pero el LDIF original deja el valor expuesto en el repo. En producción se generan los hashes con `slappasswd -s` y solo el hash se escribe al archivo.
4. **Los certificados TLS serán autofirmados** con una CA del propio proyecto. Esto es válido para un laboratorio cerrado pero inservible en internet público: cualquier cliente verá advertencias de certificado y un atacante con acceso al mismo host podría montar MITM.
5. **No hay backup, alta disponibilidad, ni hardening del sistema operativo.** Un solo contenedor por servicio, volúmenes locales, sin replicación.
6. **No hay rate limiting, lockout de cuentas, ni protección contra fuerza bruta** más allá de lo que trae cada componente por defecto.
7. **El cifrado de archivos de OwnCloud en modo *master key* cifra en disco pero no protege contra el administrador del servidor.** La llave maestra vive en el mismo servidor. Para protección frente a operadores sería necesario cifrado extremo a extremo en el cliente.
8. **No se aplica segmentación de red entre servicios.** Todos comparten la misma red Docker sin políticas de firewall internas.

**Si llegaste aquí desde Google y planeas usar esto en serio**, trata este repo como un punto de partida para aprender los conceptos y luego lee los docs oficiales de cada componente para entender cómo endurecerlo antes de exponerlo.

---

## Stack y mapeo al control de acceso

| Capa de control de acceso | Componente | Función |
|---|---|---|
| Identificación | OpenLDAP 2.x | Directorio único de usuarios con UIDs |
| Autenticación (algo que *conozco*) | OpenLDAP | Valida usuario + contraseña |
| Autenticación (algo que *tengo*) | PrivacyIDEA + FreeOTP | Valida el token OTP generado en el móvil |
| Autorización | OwnCloud | Permisos de lectura/escritura sobre carpetas |
| Auditoría | Logs de OpenLDAP, PrivacyIDEA, OwnCloud | Registro de eventos de acceso |

## Estado del proyecto

El estado detallado, los bloqueadores y el plan por fases viven en [`docs/estado-proyecto.md`](docs/estado-proyecto.md), que se actualiza en cada avance. Resumen actual:

- [x] Estructura del repositorio y documentación base
- [x] OpenLDAP con dos unidades organizacionales (Desarrollo, Seguridad) y usuarios sembrados
- [ ] PrivacyIDEA integrado con el LDAP como *resolver*
- [ ] Token TOTP enrolado desde FreeOTP
- [ ] OwnCloud integrado con LDAP y doble factor
- [ ] Cifrado de archivos compartidos activado
- [ ] Memoria técnica y presentación final

## Arranque rápido (LDAP)

```bash
# 1. Levantar OpenLDAP
cd compose
docker compose --env-file ../.env up -d openldap

# 2. Verificar que los 6 usuarios + la cuenta de servicio quedaron bien
cd ..
./scripts/ldap-verify.sh
```

Si el script termina con `Todo OK` significa que el directorio está operativo y listo para que PrivacyIDEA y OwnCloud lo consuman.

## Estructura del repositorio

```
otp-secured-cloud/
├── compose/              docker-compose.yml con todos los servicios
├── ldap/
│   └── bootstrap/        LDIFs que siembran el directorio al primer arranque
├── privacyidea/          Configuración del servicio de OTP (pendiente)
├── owncloud/             Configuración del servicio de almacenamiento (pendiente)
├── certs/                Certificados TLS autofirmados del proyecto
├── scripts/              Utilidades (pruebas, regenerar certs, etc.)
└── docs/                 Memoria técnica, diagramas, conceptos básicos
```

## Documentación

- [Estado del proyecto](docs/estado-proyecto.md) — documento vivo con avance, bloqueadores y plan por fases
- [Guía paso a paso para el equipo](docs/guia-equipo.md) — cómo clonar y probar el proyecto en tu máquina
- [Conceptos básicos de 2FA y OTP](docs/conceptos-basicos.md)
- [Arquitectura del sistema](docs/arquitectura.md)
- [Diseño del árbol LDAP](docs/arbol-ldap.md)
- [Preguntas abiertas al profesor](docs/preguntas-abiertas.md)

## Integrantes

Equipo del proyecto final de Seguridad Informática Avanzada, semestre 2026-2:

- Arellanes Conde Esteban
- Ferreira Rojas Mauricio
- López Segundo Luis Iván
- Olvera González Arely
- Rufino López María Elena
- Salgado Miranda Jorge

## Licencia

Proyecto académico. Código liberado con fines educativos.

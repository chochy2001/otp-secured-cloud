# Estado del proyecto

Documento vivo. Se actualiza en cada commit que cambie el avance.

**Última actualización:** 2026-04-24
**Fecha de entrega:** 2026-05-29 (viernes)
**Duración de la exposición:** 30 minutos, todos los integrantes participan.

## 1. Resumen ejecutivo

| Componente | Estado | Evidencia |
|---|---|---|
| Repositorio en GitHub | Operativo | `chochy2001/otp-secured-cloud`, rama `main` sincronizada con `origin/main` |
| Colaboradores del equipo | En progreso | Arely aceptada; Mauricio, María Elena, Esteban y Luis Iván pendientes |
| OpenLDAP | Funcional | `scripts/ldap-verify.sh` pasa con `Todo OK` |
| PrivacyIDEA | Funcional | Servicio en Docker, admin inicial, resolver LDAP y realm verificados con `scripts/privacyidea-verify.sh` |
| Certificados TLS (CA propia) | Por implementar | Pendiente |
| OwnCloud | Bloqueado | Depende de respuesta del profesor (versión 10 vs OCIS) |
| Cifrado de archivos compartidos | Bloqueado | Depende de OwnCloud |
| Documentación del entregable | Parcial | Conceptos básicos, árbol, arquitectura y guía de equipo listos; falta memoria técnica consolidada, conclusiones, glosario y bibliografía |
| Presentación de 30 min | Por preparar | Pendiente |

Estados usados: funcional, parcial, por implementar, por preparar y bloqueado.

## 2. Entregables del profesor y su estado

Según el PDF oficial del proyecto, el entregable consta de tres bloques:

### 2.1 Documentación del proyecto (40% de la evaluación)

| Sección requerida | Estado | Archivo |
|---|---|---|
| Portada | Pendiente | Pendiente |
| Introducción | Pendiente | Pendiente |
| Índice | Pendiente, se genera al final | Pendiente |
| Índice de figuras con referencia | Pendiente | Pendiente |
| Conceptos básicos de 2FA mediante tokens OTP | Redactado | [`conceptos-basicos.md`](conceptos-basicos.md) |
| Diagrama detallado de la solución | Diagrama de trabajo listo; falta versión renderizada | [`arquitectura.md`](arquitectura.md) |
| Memoria técnica paso a paso | Parcial: LDAP documentado, falta PrivacyIDEA, TLS y OwnCloud | varios |
| Conclusiones individuales y por equipo | Pendiente | Pendiente |
| Bibliografía | Pendiente | Pendiente |
| Glosario de términos | Pendiente | Pendiente |

### 2.2 Exposición del proyecto (30% de la evaluación)

| Tarea | Estado |
|---|---|
| Definir orden de intervenciones y tiempos por integrante | Pendiente |
| Guion de la demo en vivo | Pendiente |
| Snapshot del entorno como respaldo | Pendiente |
| Grabación del flujo completo como respaldo | Pendiente |

### 2.3 Funcionamiento (30% de la evaluación, 5 componentes × 6%)

| Validación | Estado | Notas |
|---|---|---|
| i. Alta de usuarios en LDAP | Hecho | 6 usuarios + 1 cuenta de servicio, verificado |
| ii. Integración con PrivacyIDEA | Hecho | Resolver LDAP `sia-ldap` y realm `sia` configurados |
| iii. Emisión de token OTP desde FreeOTP | Hecho | `scripts/privacyidea-enroll-test-token.sh` enrola con `genkey=1`, calcula TOTP local y valida vía API; flujo con FreeOTP documentado para la demo |
| iv. Implementación de OwnCloud | Bloqueado | Espera decisión 10 vs OCIS |
| v. Integración 2FA LDAP + OTP | Bloqueado | Depende de iii y iv |

## 3. Plan por fases

### Fase 1: Estructura del repositorio
- [x] README con aviso académico de seguridad
- [x] `.gitignore`, `.env`, `.env.example`
- [x] Estructura de carpetas (`compose/`, `ldap/`, `privacyidea/`, `owncloud/`, `certs/`, `scripts/`, `docs/`)

### Fase 2: Directorio LDAP
- [x] `osixia/openldap:1.5.0` en Docker Compose
- [x] Base DN `dc=sia,dc=unam,dc=mx`
- [x] OU Desarrollo + 3 usuarios
- [x] OU Seguridad + 3 usuarios
- [x] OU Servicios + cuenta `svc-owncloud` de solo lectura, separada del filtro de usuarios humanos
- [x] ACL de lectura para la cuenta de servicio, sin exponer `userPassword`
- [x] Script `scripts/ldap-verify.sh` que valida admin, conteo de usuarios, lectura de servicio y rechazo de credenciales inválidas
- [x] Documentación del diseño del árbol (`docs/arbol-ldap.md`)
- [x] Guía para el equipo (`docs/guia-equipo.md`)

### Fase 3: PrivacyIDEA
- [x] Servicio en `docker-compose.yml`
- [x] Imagen propia reproducible con `PRIVACYIDEA_VERSION=3.10.2`
- [x] Bootstrap idempotente de llaves, base SQLite y admin inicial
- [x] Configuración del resolver LDAP y realm por API con `scripts/privacyidea-configure.sh`
- [x] Validación de servicio, admin, resolver, conteo de 6 usuarios y realm con `scripts/privacyidea-verify.sh`
- [x] Documentar el how-to en `privacyidea/README.md` (requisitos, arranque, verificación, configuración automatizada y alternativa por UI)
- [x] Script `scripts/privacyidea-validate-otp.sh` que valida un OTP contra `POST /validate/check`, el mismo endpoint que usará OwnCloud
- [x] Documentar el flujo de enrolamiento del token TOTP desde la UI y el escaneo del QR con FreeOTP
- [x] Script `scripts/privacyidea-enroll-test-token.sh` que enrola con `genkey=1`, imprime la URL `otpauth://` y calcula+valida el TOTP localmente con Python stdlib, sin depender de un teléfono
- [ ] Paso manual del equipo antes de la exposición: enrolar un token en un móvil real con FreeOTP usando la URL que imprime el script

### Fase 4: Certificados TLS (CA propia)
- [ ] Script en `scripts/` que genera CA + certs de cada servicio
- [ ] Activar LDAPS en el contenedor de OpenLDAP, publicar puerto 6636
- [ ] Activar HTTPS en PrivacyIDEA con el cert del paso anterior
- [ ] Documentar generación y confianza de la CA

### Fase 5: OwnCloud y 2FA
Bloqueado por las preguntas abiertas al profesor. Ver [`preguntas-abiertas.md`](preguntas-abiertas.md).

- [ ] Respuesta a versión: 10 Server vs OCIS
- [ ] Respuesta a modelo de autorización: grupos LDAP vs permisos OwnCloud
- [ ] Respuesta a alcance del cliente: solo web vs también escritorio/móvil
- [ ] Implementar OwnCloud con el backend LDAP
- [ ] Integrar `twofactor_privacyidea`
- [ ] Configurar permisos y compartir archivos entre usuarios

### Fase 6: Cifrado de archivos compartidos
- [ ] Activar módulo *Server Side Encryption* modo *master key* (AES-256)
- [ ] Demostrar archivos cifrados en disco
- [ ] Validar que el destinatario puede abrirlos al compartir

### Fase 7: Auditoría y bitácoras
Depende de respuesta del profesor sobre si se muestra en demo. Independientemente, documentar.

- [ ] Habilitar niveles de log adecuados en OpenLDAP, PrivacyIDEA, OwnCloud
- [ ] Mostrar ejemplos de eventos: login exitoso, login fallido, enrolamiento de token, acceso a archivo

### Fase 8: Documentación final y entrega
- [ ] Portada
- [ ] Introducción
- [ ] Conclusiones individuales (6) + conclusión de equipo
- [ ] Glosario (LDAP, OTP, TOTP, HOTP, IGA, NHI, ACL, RBAC, 2FA, MFA, deduplicación, etc.)
- [ ] Bibliografía (RFCs, documentación oficial de cada componente)
- [ ] Índice de figuras
- [ ] Consolidar memoria técnica en un PDF final

### Fase 9: Presentación
- [ ] Slides o guion de 30 min
- [ ] División de tiempos por integrante
- [ ] Ensayo al menos una vez completo
- [ ] Snapshot del entorno listo como plan B
- [ ] Grabación del flujo completo como plan C

## 4. Bloqueadores actuales

### 4.1 Preguntas al profesor sin responder (4)

Ver [`preguntas-abiertas.md`](preguntas-abiertas.md) para el detalle.

1. Alcance del cliente: solo web vs también escritorio/móvil.
2. Versión de OwnCloud: 10 Server vs OCIS.
3. Modelo de autorización: grupos LDAP vs permisos internos de OwnCloud.
4. Auditoría en la demo: bitácoras en vivo vs solo descripción.

Mientras estas no lleguen, se avanza en todo lo que no dependa de OwnCloud.

### 4.2 Invitaciones de GitHub pendientes de aceptar (4)

| Integrante | Username de GitHub | Estado |
|---|---|---|
| Olvera González Arely | `AOG-are` | Aceptada |
| Ferreira Rojas Mauricio | `Mauferreira11` | Pendiente |
| Rufino López María Elena | `MariaElenaRufinoLopez` | Pendiente |
| Arellanes Conde Esteban | `EstebanArellanesConde` | Pendiente |
| López Segundo Luis Iván | `IvanLLS` | Pendiente |
| Salgado Miranda Jorge | `chochy2001` | Propietario |

## 5. Historial reciente de avance

### 2026-04-24
- Repositorio creado en GitHub con commits modulares limpios.
- OpenLDAP verificado de punta a punta con `scripts/ldap-verify.sh`.
- Contraseñas consolidadas al patrón `sia-<rol>-2026`.
- Guía paso a paso para el equipo publicada en `docs/guia-equipo.md`.
- Invitaciones a los 5 colaboradores enviadas; Arely aceptada.
- PDF de preguntas preparado y compartido con el profesor fuera del repo.
- Revisión de estilo y consistencia de toda la documentación (sin emojis, sin caracteres decorativos, ASCII básico en los diagramas).
- Cuenta de servicio `svc-owncloud` reclasificada a `simpleSecurityObject` y `organizationalRole` para que no aparezca en búsquedas de usuarios humanos con filtro `(objectClass=inetOrgPerson)`.
- `scripts/ldap-verify.sh` endurecido: ahora valida conteos exactos (3 en Desarrollo, 3 en Seguridad, 6 humanos en total) y rechazo de contraseña inválida.
- Agregados `README.md` placeholder en `certs/`, `owncloud/` y `privacyidea/` para documentar el rol de cada carpeta antes de tener su contenido final.
- PrivacyIDEA agregado al `docker-compose.yml` con imagen propia, configuración reproducible y resolver LDAP funcional.

## 6. Próximo hito objetivo

**Enrolar un token TOTP en PrivacyIDEA y validarlo con FreeOTP**, sin depender de ninguna respuesta del profesor. Esto desbloquea la validación del componente iii (emisión de OTP) de la evaluación de funcionamiento.

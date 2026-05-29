# Conceptos básicos de doble factor de autenticación mediante tokens OTP

## 1. Control de acceso: las cuatro capas

El control de acceso en sistemas modernos se descompone en cuatro capas interdependientes. Si falta alguna, no existe un control de acceso completo.

### 1.1 Identificación

Asignar un identificador único a cada sujeto (usuario, servicio, dispositivo). El reto no es solo crear el identificador sino garantizar que **sea único dentro del conjunto de la población**. Este proceso se llama **deduplicación**: validar que no existan dos registros que correspondan a la misma persona.

Ejemplos:
- **Bases deduplicadas:** SAT, INE (registros verificados, incluyendo domicilio y biometría).
- **Bases no deduplicadas:** CURP (una persona puede terminar con varias CURPs por errores de captura).

El concepto general de gestión de estas identidades se llama **IGA (Identity Governance and Administration)**, e incluye también **NHI (Non-Human Identity)** para servicios y dispositivos. La centralización típica se hace con un directorio como LDAP.

En este proyecto: cada usuario tiene un UID único dentro de OpenLDAP (`uid=usuario.desarrolloN`).

### 1.2 Autenticación

Probar que el sujeto es quien dice ser. Se basa en tres familias de factores:

| Factor | Ejemplos |
|---|---|
| Algo que **conozco** | Contraseña, PIN, frase de paso |
| Algo que **tengo** | Token OTP, tarjeta, llave FIDO2 |
| Algo que **soy** | Huella, iris, rostro, voz |

Las combinaciones reciben nombres estándar:
- **1FA:** un solo factor (ej. solo contraseña).
- **2FA:** dos factores *de familias distintas* (ej. contraseña + OTP).
- **MFA:** dos o más factores.

> Dos contraseñas distintas **no** son 2FA; los factores deben venir de familias diferentes.

En este proyecto: primer factor = contraseña en LDAP (*conozco*), segundo factor = token TOTP generado por FreeOTP, Proton Authenticator u otra app TOTP (*tengo*).

### 1.3 Autorización

Definir qué puede hacer el sujeto una vez autenticado: leer, escribir, administrar, compartir, etc. Los modelos típicos son:

- **ACL (Access Control List):** lista de permisos asociados a cada recurso.
- **RBAC (Role-Based Access Control):** permisos asignados a roles, y roles asignados a usuarios.

En este proyecto: OwnCloud gestiona permisos sobre carpetas y archivos compartidos. Cada usuario solo ve y modifica lo que corresponde a su rol.

### 1.4 Auditoría

Registrar toda la actividad del usuario dentro del sistema: inicios de sesión, consultas, modificaciones, exportaciones, fallos de autenticación. Sin este registro es imposible investigar incidentes ni detectar accesos indebidos.

En este proyecto: los logs de OpenLDAP (bind exitoso/fallido), PrivacyIDEA (validación de token) y OwnCloud (acceso a archivos) conforman la bitácora.

> Nota: la cuarta capa (auditoría) no es evaluable en este proyecto. Se mantiene en este capítulo para no romper el marco conceptual de cuatro capas. Ver "Prefacio" para el contexto completo de alcance y `docs/auditoria.md` para los logs capturados.

## 2. One Time Password (OTP)

Un **OTP** es una contraseña que sirve **una sola vez**. Si un atacante la intercepta, ya expiró cuando intente reutilizarla. Hay dos variantes principales:

### 2.1 HOTP: HMAC-based One Time Password (RFC 4226)

El código se deriva de un **contador**. Cliente y servidor empiezan con el mismo contador y lo incrementan en cada uso.

- Pro: no depende del reloj.
- Contra: si el contador se desincroniza (usuario genera códigos que no usa), hay que resincronizarlo.

### 2.2 TOTP: Time-based One Time Password (RFC 6238)

El código se deriva del **tiempo actual**, típicamente en ventanas de 30 segundos.

- Pro: nunca se desincroniza por uso; solo requiere relojes alineados.
- Contra: sensible a desfase de reloj entre dispositivo y servidor.

**Este proyecto usa TOTP**, que es el estándar actual y el modo compatible con FreeOTP, Proton Authenticator, Google Authenticator y apps equivalentes.

### 2.3 Cómo funciona matemáticamente

Tanto HOTP como TOTP usan HMAC-SHA1 (o SHA-256/SHA-512) sobre un **secreto compartido** y un **contador o timestamp**:

```
TOTP = truncate( HMAC-SHA1( secreto, floor(unix_time / 30) ) )
```

El secreto se entrega al móvil una sola vez (típicamente escaneando un QR). A partir de ahí, tanto el móvil como el servidor pueden generar el mismo código cada 30 segundos sin comunicarse entre sí.

## 3. Arquitectura 2FA con LDAP + PrivacyIDEA + OwnCloud

El esquema típico es:

1. El usuario va al portal de OwnCloud y entrega **usuario + contraseña + OTP**.
2. OwnCloud pide al **LDAP** que valide usuario + contraseña (bind).
3. Si es correcto, el plugin `twofactor_privacyidea` le pregunta a **PrivacyIDEA** si el OTP es válido para ese usuario.
4. PrivacyIDEA busca al usuario en su **resolver LDAP** (el mismo OpenLDAP), localiza el token que le enrolaron previamente, y valida el código contra el secreto almacenado.
5. Si los dos factores pasan, OwnCloud abre sesión.

La clave conceptual: **el LDAP es la única fuente de identidad**, tanto para OwnCloud como para PrivacyIDEA. No hay usuarios duplicados en cada sistema.

## 4. Referencias

- RFC 4226: HOTP
- RFC 6238: TOTP
- Documentación de PrivacyIDEA: <https://privacyidea.readthedocs.io/>
- Documentación de OwnCloud (user_ldap y twofactor): <https://doc.owncloud.com/>

# Continuidad del proyecto

**Fecha:** 2026-05-14

Este documento deja el estado consolidado para poder continuar el trabajo sin depender de memoria de sesiones anteriores. La fuente de verdad sigue siendo el repositorio `chochy2001/otp-secured-cloud` en la rama `main`.

## Estado consolidado

El proyecto está funcional, documentado y validado para el alcance académico pedido:

| Área | Estado | Evidencia |
|---|---|---|
| Repositorio | Listo | Rama `main` sincronizada con `origin/main` al inicio de este cierre |
| Arranque de laboratorio | Listo | `./scripts/bootstrap.sh` levanta, configura y valida todo |
| OpenLDAP | Listo | 6 usuarios humanos, cuenta de servicio, ACL y LDAPS |
| privacyIDEA | Listo | Resolver `sia-ldap`, realm `sia`, TOTP y validación por API |
| OwnCloud | Listo | OwnCloud 10.15, LDAP por LDAPS, plugin 2FA, cifrado y compartidos |
| Caddy/TLS | Listo | OwnCloud expuesto en `https://localhost:9443` con certificado de la CA local |
| Cifrado | Listo | Server Side Encryption con master key y cabecera `HBEGIN` validada |
| Compartidos | Listo | Prueba OCS API con emisor y destinatario LDAP |
| Documentación | Listo | README, memoria técnica, documento final, guion, slides, guías y manual TOTP |
| Entregable derivado | Regenerable | `./scripts/build-pdf.sh` produce HTML, DOCX y PDF en `build/` |

## Funcionalidad ya cubierta

Lo siguiente ya está implementado y no requiere más desarrollo para cumplir el proyecto:

1. Alta de usuarios LDAP en `ou=Desarrollo` y `ou=Seguridad`.
2. Cuenta de servicio `cn=svc-owncloud,ou=Servicios,...` separada de usuarios humanos.
3. LDAPS con CA local del proyecto.
4. privacyIDEA con resolver LDAP y realm `sia`.
5. Token TOTP compatible con FreeOTP, Proton Authenticator y apps equivalentes.
6. OwnCloud con autenticación LDAP como primer factor.
7. Plugin `twofactor_privacyidea` como segundo factor.
8. Cuenta local `admin` de OwnCloud excluida explícitamente del reto OTP por ser mantenimiento local.
9. Cifrado de archivos en disco con Server Side Encryption.
10. Compartición de archivos entre usuarios y lectura descifrada por destinatario autorizado.
11. Script único `./scripts/bootstrap.sh` para reproducir y validar el laboratorio.
12. Auditoría como complemento académico no evaluable.

## Pendientes reales

No quedan pendientes técnicos automatizables para el alcance del profesor. Lo que falta antes de presentar son tareas humanas:

| Pendiente | Responsable | Cómo cerrarlo |
|---|---|---|
| Revisar visualmente el PDF final | Equipo | Abrir `build/entregable-otp-secured-cloud.pdf` y revisar portada, tablas, figuras y bibliografía |
| Confirmar token físico de demo | Quien presente la demo | Abrir Proton Authenticator o FreeOTP y verificar que `TOTP_usuario_desarrollo1` genera códigos |
| Ensayar la exposición | Equipo completo | Usar `docs/guion-exposicion.md` y `docs/presentacion.md` |
| Ensayar demo manual | Presentador técnico | Entrar a `https://localhost:9443` con `usuario.desarrollo1` y el OTP del celular |
| Preparar plan B | Equipo | Tener terminal con `./scripts/bootstrap.sh --no-build --skip-tests` y PDF local abierto |
| Grabación opcional de respaldo | Equipo | Grabar el flujo descrito en `docs/como-probar.md` si el profesor lo permite |

## Reglas para no romper el estado actual

- No correr scripts automáticos pasando `usuario.desarrollo1` a menos que se quiera rotar intencionalmente el token del teléfono.
- Para pruebas automatizadas usar `usuario.desarrollo2`, `usuario.desarrollo3` y `usuario.seguridad1`.
- No versionar archivos de `build/`, certificados privados ni artefactos generados.
- Si se edita cualquier Markdown del entregable, regenerar con `./scripts/build-pdf.sh`.
- Si se cambia Docker, LDAP, privacyIDEA, OwnCloud o scripts, validar con `./scripts/bootstrap.sh`.
- Si se borra el volumen Docker con `down -v`, hay que volver a enrolar o confirmar tokens porque se reconstruye el estado.

## Validación recomendada para continuar

Para comprobar que el entorno sigue bien:

```bash
git pull origin main
./scripts/bootstrap.sh
```

Si el stack ya está levantado y solo se quiere validar sin reconstruir imágenes:

```bash
./scripts/bootstrap.sh --no-build
```

Si solo se quiere confirmar salud sin correr pruebas end-to-end:

```bash
./scripts/bootstrap.sh --no-build --skip-tests
```

Para no tocar el token físico de `usuario.desarrollo1`, la cadena segura manual es:

```bash
./scripts/ldap-verify.sh
./scripts/privacyidea-verify.sh
./scripts/owncloud-verify.sh
./scripts/owncloud-login-verify.sh usuario.desarrollo2
./scripts/owncloud-share-verify.sh usuario.desarrollo3 usuario.seguridad1
```

## Mejoras futuras fuera del alcance

Estas ideas son válidas para continuar después, pero no son necesarias para la entrega académica actual:

| Mejora | Motivo |
|---|---|
| Sacar secretos de `.env` versionado | Requisito para un entorno real |
| Certificados públicos o CA institucional | Evitar advertencias de navegador |
| Alta disponibilidad para LDAP, privacyIDEA y OwnCloud | Evitar punto único de falla |
| Backups y restauración probada | Recuperación ante pérdida de volumen |
| Rate limiting y lockout de cuentas | Reducir fuerza bruta |
| SIEM o centralización de logs | Mejor auditoría operativa |
| Cifrado extremo a extremo | Proteger contra administradores del servidor |
| Política real de contraseñas por usuario | Sustituir password académico compartido |

## Documentos clave

| Documento | Uso |
|---|---|
| `README.md` | Entrada principal del repo |
| `docs/estado-proyecto.md` | Estado vivo y trazabilidad |
| `docs/cierre-sesion.md` | Puertos, credenciales y comandos para retomar |
| `docs/documento-final.md` | Resumen ejecutivo para explicar arquitectura, pruebas y defensa |
| `docs/como-probar.md` | Checklist de prueba y demo |
| `docs/guion-exposicion.md` | Orden de exposición por integrante |
| `docs/manual-freeotp.md` | Enrolamiento del token físico |
| `docs/memoria-tecnica.md` | Detalle técnico por fases |

# Bootstrap del directorio LDAP

Los archivos LDIF de este directorio se cargan automáticamente la primera vez que arranca el contenedor de OpenLDAP. Se procesan en orden alfabético por nombre de archivo.

## Contenido

| Archivo | Qué crea |
|---|---|
| `00-acl-service-read.ldif` | ACL que permite a la cuenta de servicio leer usuarios sin exponer contraseñas |
| `01-ous.ldif` | Unidades organizacionales `Desarrollo`, `Seguridad` y `Servicios` |
| `02-users-desarrollo.ldif` | Tres usuarios bajo `ou=Desarrollo` |
| `03-users-seguridad.ldif` | Tres usuarios bajo `ou=Seguridad` |
| `04-service-account.ldif` | Cuenta de servicio `cn=svc-owncloud,ou=Servicios` |

## Nota sobre contraseñas

Los LDIFs usan hashes `{SSHA}` generados con `slappasswd` para no sembrar `userPassword` en texto plano dentro del directorio. Las contraseñas académicas equivalentes siguen documentadas en `.env` para que el equipo pueda levantar el laboratorio sin intercambiar secretos por otro canal.

Si cambias `LDAP_USER_PASSWORD` o `LDAP_SERVICE_PASSWORD` en `.env`, también debes regenerar y reemplazar los hashes de estos LDIFs antes de reconstruir el directorio:

```bash
slappasswd -s "contrasena"
# genera una cadena con formato {SSHA}xxxxx...
```

En producción, además de usar hashes, las contraseñas no deberían versionarse en `.env`.

## Reimportar si cambias los LDIFs

Si modificas los archivos, el contenedor solo los reimporta en el primer arranque sobre volúmenes vacíos. Para aplicar cambios:

```bash
cd compose
docker compose down -v   # elimina los volúmenes (¡borra datos!)
docker compose up -d openldap
```

Alternativa sin borrar datos: aplicar los cambios con `ldapmodify` / `ldapadd` directamente contra el servidor corriendo.

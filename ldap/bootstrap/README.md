# Bootstrap del directorio LDAP

Los archivos LDIF de este directorio se cargan automáticamente la primera vez que arranca el contenedor de OpenLDAP. Se procesan en orden alfabético por nombre de archivo.

## Contenido

| Archivo | Qué crea |
|---|---|
| `01-ous.ldif` | Unidades organizacionales `Desarrollo`, `Seguridad` y `Servicios` |
| `02-users-desarrollo.ldif` | Tres usuarios bajo `ou=Desarrollo` |
| `03-users-seguridad.ldif` | Tres usuarios bajo `ou=Seguridad` |
| `04-service-account.ldif` | Cuenta de servicio `cn=svc-owncloud,ou=Servicios` |

## Nota sobre contraseñas

En estos LDIFs las contraseñas están en texto plano por claridad del ejemplo académico. OpenLDAP las hashea al importar de acuerdo con la política configurada. Para un entorno productivo, generar los hashes previamente con:

```bash
slappasswd -s "contrasena"
# → {SSHA}xxxxx...
```

y reemplazar el valor de `userPassword` por la cadena resultante.

## Reimportar si cambias los LDIFs

Si modificas los archivos, el contenedor solo los reimporta en el primer arranque sobre volúmenes vacíos. Para aplicar cambios:

```bash
cd compose
docker compose down -v   # elimina los volúmenes (¡borra datos!)
docker compose up -d openldap
```

Alternativa sin borrar datos: aplicar los cambios con `ldapmodify` / `ldapadd` directamente contra el servidor corriendo.

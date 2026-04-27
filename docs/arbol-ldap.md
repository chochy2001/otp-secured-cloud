# Diseño del árbol LDAP

## Visión general

```
dc=sia,dc=unam,dc=mx                          (base DN raíz)
|
|-- cn=admin                                   (admin del directorio)
|
|-- ou=Desarrollo                              (OU exigida por el anexo)
|   |-- uid=usuario.desarrollo1
|   |-- uid=usuario.desarrollo2
|   `-- uid=usuario.desarrollo3
|
|-- ou=Seguridad                               (OU exigida por el anexo)
|   |-- uid=usuario.seguridad1
|   |-- uid=usuario.seguridad2
|   `-- uid=usuario.seguridad3
|
`-- ou=Servicios                               (cuentas no humanas)
    `-- cn=svc-owncloud                        (bind DN para aplicaciones)
```

## Valores que esperan OwnCloud y PrivacyIDEA

Cuando se configura el *LDAP User Backend* o el *User Resolver*, cada aplicación pide estos campos. Aquí están los valores que corresponden al árbol de arriba.

| Campo | Valor |
|---|---|
| Host | `openldap` (nombre del contenedor en la red Docker) |
| Port | `636` dentro de Docker para LDAPS; `6636` desde el host; `389` queda disponible solo como transición |
| Base DN | `dc=sia,dc=unam,dc=mx` |
| Bind DN | `cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx` |
| Bind Password | valor de `LDAP_SERVICE_PASSWORD` en `.env` |
| User Search Base | `dc=sia,dc=unam,dc=mx` (busca en ambas OUs) |
| User Login Attribute | `uid` |
| User Filter | `(objectClass=inetOrgPerson)` |

## Decisiones de diseño

### Base DN raíz `dc=sia,dc=unam,dc=mx`

Refleja el contexto académico: **S**eguridad **I**nformática **A**vanzada en la UNAM. Convención estándar de LDAP a partir del dominio `sia.unam.mx`.

### Atributo de inicio de sesión `uid`

Es la convención histórica en OpenLDAP con `inetOrgPerson`. Active Directory usa `sAMAccountName`; como estamos en OpenLDAP, `uid` es lo natural y lo que esperan las pantallas de configuración de OwnCloud y PrivacyIDEA por defecto.

### ObjectClass `inetOrgPerson`

Es la clase que da los atributos que una aplicación necesita para autenticar: `uid`, `cn`, `sn`, `mail`, `userPassword`. Si se requiriera que los mismos usuarios entraran a un sistema Linux vía SSH, se añadiría `posixAccount` para los atributos `uidNumber`, `gidNumber`, `homeDirectory` y `loginShell`; no es el caso en este proyecto.

### Cuenta de servicio separada en `ou=Servicios`

Las aplicaciones (OwnCloud, PrivacyIDEA) necesitan hacer *bind* contra el directorio para **buscar** usuarios, no para iniciar sesión como si fueran ellos. Esto exige una cuenta con **permiso de solo lectura** sobre las OUs de usuarios.

Buenas prácticas aplicadas:
- No se reutiliza `cn=admin` (que tiene permisos de escritura).
- Se separa del árbol de usuarios humanos para evitar confusiones de conteo y de autorización.
- No usa `inetOrgPerson`, para que no aparezca en búsquedas de usuarios humanos.
- La ACL `00-acl-service-read.ldif` le permite leer usuarios, pero no leer `userPassword`.
- Un solo `svc-owncloud` sirve para ambas aplicaciones porque sus permisos de lectura son idénticos.

### Grupos LDAP: *pendiente* de decisión con el profesor

El diseño actual **no incluye grupos LDAP todavía** (p. ej. `groupOfNames`). Está pendiente confirmar si el profesor espera que los permisos sobre carpetas en OwnCloud se modelen vía grupos sincronizados desde LDAP, o si basta con administrarlos dentro de OwnCloud una vez autenticado el usuario (ver `docs/preguntas-abiertas.md`).

Si se opta por grupos, la rama esperada sería:

```
ou=Grupos,dc=sia,dc=unam,dc=mx
|-- cn=desarrollo (grupo con miembros de Desarrollo)
`-- cn=seguridad (grupo con miembros de Seguridad)
```

## Cómo verificar el árbol

Una vez levantado el contenedor:

```bash
# Listar todo bajo la raíz
docker exec -it otpsec-openldap ldapsearch -x \
  -H ldap://localhost \
  -b "dc=sia,dc=unam,dc=mx" \
  -D "cn=admin,dc=sia,dc=unam,dc=mx" \
  -w "$LDAP_ADMIN_PASSWORD"

# Solo usuarios de Desarrollo
docker exec -it otpsec-openldap ldapsearch -x \
  -H ldap://localhost \
  -b "ou=Desarrollo,dc=sia,dc=unam,dc=mx" \
  -D "cn=admin,dc=sia,dc=unam,dc=mx" \
  -w "$LDAP_ADMIN_PASSWORD" \
  "(objectClass=inetOrgPerson)" uid cn mail

# Validar que la cuenta de servicio puede hacer bind
docker exec -it otpsec-openldap ldapwhoami -x \
  -H ldap://localhost \
  -D "cn=svc-owncloud,ou=Servicios,dc=sia,dc=unam,dc=mx" \
  -w "$LDAP_SERVICE_PASSWORD"
```

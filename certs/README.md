# Certificados

CA local del proyecto y certificados de servidor para OpenLDAP y PrivacyIDEA. Toda esta carpeta excepto este `README.md` está ignorada por git: las llaves privadas y certificados se generan localmente con un script y nunca se versionan.

## Generación

Desde la raíz del repositorio:

```bash
./scripts/generate-certs.sh
```

El script es idempotente: si los archivos ya existen y validan contra la CA actual, no se regeneran. Para forzar la regeneración (por ejemplo, después de cambiar SANs):

```bash
./scripts/generate-certs.sh --force
```

## Archivos producidos

| Archivo | Para qué |
|---|---|
| `ca.key`, `ca.crt` | Autoridad certificadora local del proyecto. RSA 4096, válida 10 años. |
| `openldap.key`, `openldap.crt` | Certificado del servidor LDAP, firmado por la CA. SANs: `openldap`, `localhost`, `127.0.0.1`, `::1`. |
| `privacyidea.key`, `privacyidea.crt` | Certificado del servidor de PrivacyIDEA, firmado por la CA. SANs: `privacyidea`, `localhost`, `127.0.0.1`, `::1`. |
| `ca.srl` | Número de serie incremental que mantiene OpenSSL. No es secreto pero no se versiona. |

## Cómo se usan

- **OpenLDAP** monta toda la carpeta como `/container/service/slapd/assets/certs/` y se le pasa el nombre de archivo de cada cert vía variables de entorno (`LDAP_TLS_CRT_FILENAME`, `LDAP_TLS_KEY_FILENAME`, `LDAP_TLS_CA_CRT_FILENAME`).
- **PrivacyIDEA** monta el certificado y llave del servidor (`privacyidea.crt`, `privacyidea.key`) y también `ca.crt` para validar LDAPS hacia OpenLDAP.
- Los **scripts del proyecto** (`scripts/privacyidea-*.sh`) le pasan a `curl` el flag `--cacert certs/ca.crt` cuando hablan vía HTTPS, para que confíe en la CA local sin importar advertencias del sistema.

## Confiar en la CA desde otros clientes

Si en algún momento se quiere acceder a las URLs HTTPS desde un navegador o cliente que no use estos scripts, hay que importar `ca.crt` como autoridad confiable:

- macOS (Keychain Access): doble clic en `ca.crt`, marcar "Always Trust" en la cadena.
- Linux (Debian/Ubuntu): `sudo cp ca.crt /usr/local/share/ca-certificates/otp-secured-cloud.crt && sudo update-ca-certificates`.
- Firefox: importar manualmente en *Preferences, Privacy & Security, Certificates, View Certificates, Authorities*.

## Aviso de seguridad académica

Esta CA y los certs son artefactos de laboratorio. La llave privada `ca.key` queda en el disco del desarrollador sin protección de contraseña. En un entorno real:

- la CA viviría en una máquina aislada o un HSM,
- las llaves privadas estarían cifradas con contraseña,
- los certificados expirarían en plazos cortos con rotación automática (ACME, Vault PKI, etc.).

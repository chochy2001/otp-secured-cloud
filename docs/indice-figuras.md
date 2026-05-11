# Índice de figuras

Las seis figuras de este entregable se mantienen como bloques `mermaid` dentro de los archivos `.md` del repositorio. Esto permite que GitHub las renderice en línea cuando se navega el código y que `scripts/build-figures.sh` las exporte a PNG para incluirlas en el PDF final.

| Número | Figura | Archivo fuente |
|---|---|---|
| 1 | Arquitectura del sistema: componentes, conexiones HTTPS y LDAPS | `docs/arquitectura.md` |
| 2 | Árbol LDAP del proyecto: base DN, OUs, usuarios y cuenta de servicio | `docs/arbol-ldap.md` |
| 3 | Flujo de autenticación 2FA: cliente web, OwnCloud, OpenLDAP y privacyIDEA | `docs/arquitectura.md` |
| 4 | Red Docker y puertos publicados | `docs/arquitectura.md` |
| 5 | Flujo de cifrado del lado servidor: subida, almacenamiento y descarga | `docs/memoria-tecnica.md` |
| 6 | Flujo de carpetas compartidas: emisor, OCS Sharing API y destinatario | `docs/memoria-tecnica.md` |

Para regenerar las imágenes localmente desde la raíz del repositorio:

```bash
npm install -g @mermaid-js/mermaid-cli
./scripts/build-figures.sh
```

Las PNG quedan en `docs/figuras/figuraN.png`. Los binarios no se versionan en el repositorio porque la fuente de verdad es el código `mermaid` en los archivos `.md`.

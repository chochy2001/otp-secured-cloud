#!/usr/bin/env bash
#
# Hook de arranque para la imagen oficial owncloud/server.
# Registra la CA local del proyecto en el trust store del contenedor antes
# de que Apache y PHP arranquen. Esto permite validar LDAPS contra OpenLDAP
# y HTTPS contra privacyIDEA sin desactivar la verificacion de certificados.
#
# La imagen oficial carga estos hooks con "source". Por eso este archivo no
# debe cambiar opciones globales del shell como set -u, porque afectaría los
# hooks internos que se ejecutan después.

CA_FILE="/usr/local/share/ca-certificates/otp-secured-cloud-ca.crt"
CA_MARKER="/tmp/otp-secured-cloud-ca.sha256"

if [[ -f "${CA_FILE}" ]]; then
  CURRENT_CA_HASH="$(sha256sum "${CA_FILE}" | awk '{print $1}')"
  PREVIOUS_CA_HASH="$(cat "${CA_MARKER}" 2>/dev/null || true)"

  if [[ "${CURRENT_CA_HASH}" != "${PREVIOUS_CA_HASH}" ]]; then
    update-ca-certificates >/dev/null
    printf '%s\n' "${CURRENT_CA_HASH}" > "${CA_MARKER}"
  fi
fi

unset CA_FILE CA_MARKER CURRENT_CA_HASH PREVIOUS_CA_HASH

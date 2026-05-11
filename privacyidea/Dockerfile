# syntax=docker/dockerfile:1
#
# Imagen reproducible de privacyIDEA para el proyecto otp-secured-cloud.
#
# La versión de privacyIDEA se fija vía argumento de build. Las
# dependencias de Python se instalan desde el requirements.txt oficial
# de esa misma versión.

FROM python:3.11-slim-bookworm

ARG PRIVACYIDEA_VERSION=3.10.2
ENV PRIVACYIDEA_VERSION=${PRIVACYIDEA_VERSION}

# Dependencias de sistema necesarias para compilar python-ldap y
# cryptography. Se limpian los índices de apt al final para dejar la
# imagen más liviana.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libffi-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

# Actualizamos pip antes de instalar dependencias para evitar fallos de
# resolución en versiones antiguas del instalador incluido en la imagen base.
RUN curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
 && python /tmp/get-pip.py --no-cache-dir \
      "pip==25.2" \
      "setuptools==75.6.0" \
      "wheel==0.45.1" \
 && rm /tmp/get-pip.py

# Estas dependencias aparecen en el requirements oficial. Instalarlas antes
# evita que el resolvedor repita descargas pequeñas que suelen fallar por
# timeouts intermitentes en PyPI.
RUN pip install --no-cache-dir --retries 10 --timeout 180 \
      "pycparser==2.23" \
      "cffi==1.16.0" \
      "argon2-cffi-bindings==21.2.0"

# Primero fijamos todas las dependencias Python al requirements.txt que
# privacyIDEA publica para la versión elegida, y después instalamos
# privacyIDEA en esa misma versión. Este orden sigue la instalación
# determinista recomendada por la documentación oficial.
#
# Se envuelve en un bucle de hasta 3 intentos porque la respuesta de
# la API de PyPI puede truncarse ocasionalmente en redes con proxies
# o con el cache intermedio de buildkit. Entre intentos se espera
# 15 segundos para que cualquier fallo transitorio se recupere.
RUN curl -fsSL \
      "https://raw.githubusercontent.com/privacyidea/privacyidea/v${PRIVACYIDEA_VERSION}/requirements.txt" \
      -o /tmp/pi-requirements.txt \
 && for intento in 1 2 3; do \
      echo "[pip] intento ${intento}" \
      && pip install --no-cache-dir --retries 10 --timeout 300 \
           -r /tmp/pi-requirements.txt \
      && pip install --no-cache-dir --retries 10 --timeout 300 \
           "privacyidea==${PRIVACYIDEA_VERSION}" \
      && break \
      || { echo "[pip] intento ${intento} fallido"; sleep 15; }; \
      if [ "${intento}" = "3" ]; then exit 1; fi; \
    done \
 && rm -f /tmp/pi-requirements.txt

RUN mkdir -p /etc/privacyidea /data /var/log/privacyidea

COPY pi.cfg /etc/privacyidea/pi.cfg
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV PRIVACYIDEA_CONFIGFILE=/etc/privacyidea/pi.cfg
ENV PYTHONUNBUFFERED=1

EXPOSE 8443

# El healthcheck exige HTTPS y valida el certificado con la CA local.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS --cacert /etc/privacyidea/ssl/ca.crt https://localhost:8443/ > /dev/null \
   || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve"]

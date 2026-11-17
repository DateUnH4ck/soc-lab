# srv-web: servidor web (nginx, HTTP y HTTPS) con agente Wazuh.
# Base: imagen oficial del agente Wazuh (Amazon Linux 2023, multi-arquitectura).
ARG WAZUH_VERSION=4.14.9
FROM wazuh/wazuh-agent:${WAZUH_VERSION}

RUN yum install -y nginx openssl iptables-nft && yum clean all && rm -rf /var/cache/yum

# Configuración del agente (el contenedor la copia a /var/ossec al arrancar)
COPY ossec.conf /wazuh-config-mount/etc/ossec.conf
# Web de la empresa ficticia, configuración de nginx y servicio gestionado por s6
COPY rootfs/ /

# Certificado autofirmado para HTTPS (el navegador avisará: es lo normal en un lab)
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
      -keyout /etc/nginx/ssl/srv-web.key -out /etc/nginx/ssl/srv-web.crt \
      -subj "/O=Hackerlab Logistica S.L./CN=srv-web.hackerlab.local" \
      -addext "subjectAltName=DNS:srv-web.hackerlab.local,DNS:www.hackerlab.local" && \
    chmod 600 /etc/nginx/ssl/srv-web.key && \
    chmod +x /etc/cont-init.d/01-lab-init /etc/services.d/*/run

EXPOSE 80 443

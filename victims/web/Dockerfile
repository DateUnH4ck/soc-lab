# srv-web: servidor web (nginx) con agente Wazuh.
# Base: imagen oficial del agente Wazuh (Amazon Linux 2023, multi-arquitectura).
ARG WAZUH_VERSION=4.14.9
FROM wazuh/wazuh-agent:${WAZUH_VERSION}

RUN yum install -y nginx iptables-nft && yum clean all && rm -rf /var/cache/yum

# Configuración del agente (el contenedor la copia a /var/ossec al arrancar)
COPY ossec.conf /wazuh-config-mount/etc/ossec.conf
# Web de la empresa ficticia + servicio nginx gestionado por s6
COPY rootfs/ /

RUN chmod +x /etc/cont-init.d/01-lab-init /etc/services.d/*/run

EXPOSE 80

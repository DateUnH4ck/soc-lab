# srv-dns: el servidor DNS de la empresa (dnsmasq) con agente Wazuh.
# Todas las consultas quedan registradas en /var/log/dnsmasq.log y llegan a Wazuh.
# Base: imagen oficial del agente Wazuh (Amazon Linux 2023, multi-arquitectura).
ARG WAZUH_VERSION=4.14.9
FROM wazuh/wazuh-agent:${WAZUH_VERSION}

RUN yum install -y dnsmasq rsyslog bind-utils && \
    yum clean all && rm -rf /var/cache/yum

COPY ossec.conf /wazuh-config-mount/etc/ossec.conf
COPY rootfs/ /

RUN chmod +x /etc/cont-init.d/01-lab-init /etc/services.d/*/run

EXPOSE 53/udp 53/tcp
